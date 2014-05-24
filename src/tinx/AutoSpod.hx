package tinx;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;

using tink.MacroApi;
#elseif sys
import sys.db.*;
using sys.FileSystem;
using sys.io.File;
using StringTools;
#else
	#error
#end

class AutoSpod {
	#if !macro
		static var connected = false;
		static public function init(mgr:Manager<Dynamic>) {
			if (!connected) {
				initCnx();
				connected = true;
			}
			if (!TableCreate.exists(mgr)) {
				TableCreate.create(mgr);
				return;
			}
				
			var cnx : Connection = untyped mgr.getCnx();
			if( cnx == null )
				throw "SQL Connection not initialized on Manager";
			var dbName = cnx.dbName();
			var infos = mgr.dbInfos();
			
			function quote(v:String):String 
				return untyped mgr.quoteField(v);		
			
			var table = quote(infos.name);
			
			var actual:Map<String, String> = 
				switch dbName {
					case 'SQLite':
						[for (f in cnx.request('PRAGMA table_info($table)').results()) f.name => f.type];
					default: 
						[for (f in cnx.request('SHOW COLUMNS FROM $table').results()) f.Field => (f.Type : String).split('(')[0].toUpperCase()];
				}
			
			for (f in infos.fields) {
				var type = TableCreate.getTypeSQL(f.t, dbName);
				switch actual[f.name] {
					case null:
						trace('Auto SPOD: adding ${f.name} : $type');
						cnx.request('ALTER TABLE $table ADD COLUMN ${quote(f.name)} $type');
					case actual:
						if (!type.startsWith(actual))
							trace('Auto SPOD: ${f.name} should be $type but is $actual');
				}
			}
		}		
		static function initCnx() {
			var mysql = ~/^(mysql:)(\/\/(([^@\/]+)@)(([^\/:]+)(:([^\/]*))?))\/([^\/]*)$/;
	
			var auth = 4;
			var host = 6;
			var port = 8;
			var db = 9;
			
			function connectMySql() {
				var auth = mysql.matched(auth).split(':');
					
				return 
					Mysql.connect({
						user: auth[0],
						pass: auth.slice(1).join(':'),
						host: mysql.matched(host),
						port: Std.parseInt(mysql.matched(port)),
						database: mysql.matched(db)
					});
			}
			
			function getConfig(path:String) {
				path = haxe.io.Path.addTrailingSlash(path);
				return
					if ('$path/dbconfig.uri'.exists()) {
						var uri = '$path/dbconfig.uri'.getContent();
						switch uri.split(':') {
							case ['alias', dir]:
								getConfig(path + dir);
							case ['sqlite', file]:
								Sqlite.open('$path/$file');
							case v:
								if (mysql.match(uri))
									connectMySql();
								else
									throw 'invalid uri scheme: $uri';
						}
					}
					else
						Sqlite.open('$path/test.db');
			}
			
			Manager.cnx = getConfig(Sys.getCwd());
			
			Manager.initialize();
		}
	#else
		static function use() {
			var d: { macroBuild: Void->Array<Field> } = cast sys.db.RecordMacros;
			var old = d.macroBuild;
			d.macroBuild = function () {
				var fields = old();
				var pos = Context.getLocalClass().get().pos;
				fields.push({
					access: [AStatic, APrivate],
					meta: [ { name: ':noCompletion', params: [], pos: pos } ],
					pos: pos,
					name: MacroApi.tempName(),
					kind: FVar(null, macro {
						tinx.AutoSpod.init(manager);
						neko.Web.logMessage('init!');
						true;
					}),
				});
				pos.warning('adding field');
				return fields;
			}
		}
	#end
}