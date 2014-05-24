# Tinkerbell Auto SPOD Extension

This is a tink extension to make developing SPOD driven apps easier.

Use with `-lib tinx_autospod`.

## Automatic connection

The DB connection is automatically established and the `sys.db.Manager` is initialized.
By default SQLite is used on `test.db` in the current directory. To change this behavior, you can add a `dbconfig.uri` with either of the following:

- `mysql://user:password@host:port/dbname`
- `sqlite:path/to/file.db`
- `alias:path/to/directory` which will continue configuration from that directory (e.g. `alias:..` with no dbconfig in the parent directory will cause an SQLite `test.db` to be used in the parent directory)

If the connection to the database fails because it doesn't exist, auto spod will try to establish a connection through the `mysql` database (which always exists but which you may not be entitled to connect to) and then create the database and switch to it.

## Automatic table creation and update

After establishing connection, auto spod will connect use `sys.db.TableCreate` to create non-existent tables. For existing tables, it will examine them and then add any missing fields. Type mismatches will be trace (although comparison is probably too lenient). Superfluous fields are left alone.

## Disclaimer

IANADBA. It's probably a relatively bad idea to use this for production deployment. Technically there is nothing to cause data loss, but running `ALTER TABLE` statements nilly willy is hardly the best approach, particularly for complex databases. 

This project aims to make development and deployment of small/personal projects easy. Just write your SPOD classes and the actual server logic and you're ready to go.