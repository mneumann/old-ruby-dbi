/*
 * DBD driver for SQLite
 *
 * file:   SQLite.c
 * author: Michael Neumann (neumann@s-direktnet.de)
 * id:     $Id: SQLite.c,v 1.1 2001/11/14 13:38:30 michael Exp $
 * 
 * Copyright (C) 2001 by Michael Neumann.
 * Released under the same terms as Ruby itself.
 *
 */

/* TODO:
 *
 * - use IDs instead of each time rb_iv_get etc.. 
 * - check correct use of exception classes 
 * - warnings: should use rb_warn ? 
 * */

#include <sqlite.h>
#include "ruby.h"

#define USED_DBD_VERSION "0.1"

static VALUE mDBD, mSQLite;
static VALUE cDriver, cDatabase, cStatement;
static VALUE cBaseDriver, cBaseDatabase, cBaseStatement;
static VALUE eOperationalError, eDatabaseError, eInterfaceError;
static VALUE eNotSupportedError;

#define SQL_FETCH_NEXT     1
#define SQL_FETCH_PRIOR    2
#define SQL_FETCH_FIRST    3
#define SQL_FETCH_LAST     4
#define SQL_FETCH_ABSOLUTE 5 
#define SQL_FETCH_RELATIVE 6 

struct sDatabase {
  struct sqlite *conn;
  int autocommit;
};

struct sStatement {
  VALUE conn, statement;
  char **result;
  int nrow, ncolumn, row_index;
};


static VALUE
Driver_initialize(VALUE self)
{
  VALUE dbd_version = rb_str_new2(USED_DBD_VERSION);

  rb_call_super(1, &dbd_version);
   
  return Qnil;
}

static void database_free(void *p) {
  struct sDatabase *db = (struct sDatabase*) p;

  if (db->conn) {
    sqlite_close(db->conn);
    db->conn = NULL;
  }

  free(p);
}

static VALUE
Driver_connect(VALUE self, VALUE dbname, VALUE user, VALUE auth, VALUE attr)
{
  char *errmsg;
  struct sDatabase *db;
  VALUE database, errstr, h_ac; 
  int state;


  Check_Type(dbname, T_STRING);
  Check_Type(attr, T_HASH);

  database = Data_Make_Struct(cDatabase, struct sDatabase, 0, database_free, db);

  db->autocommit = 0;  /* off */

  h_ac = rb_hash_aref(attr, rb_str_new2("AutoCommit"));
  if (RTEST(h_ac)) {
    db->autocommit = 1; /* on */
  } 

  db->conn = sqlite_open(STR2CSTR(dbname), 0, &errmsg);
  if (!db->conn) {
    errstr = rb_str_new2(errmsg); 
    free(errmsg);
    rb_raise(eOperationalError, STR2CSTR(errstr));
  }

  /* AutoCommit */
  if (db->autocommit == 0) {
    state = sqlite_exec(db->conn, "BEGIN TRANSACTION", NULL, NULL, &errmsg);
    if (state != SQLITE_OK) {
      errstr = rb_str_new2(errmsg); free(errmsg);
      rb_str_cat(errstr, "(", 1); rb_str_concat(errstr, rb_str_new2(sqliteErrStr(state))); rb_str_cat(errstr, ")", 1);
      rb_raise(eDatabaseError, STR2CSTR(errstr));
    }
  }

  return database;
}

static VALUE
Database_aref(VALUE self, VALUE key)
{
  struct sDatabase *db;

  Check_Type(key, T_STRING);

  if (rb_str_cmp(key, rb_str_new2("AutoCommit")) == 0) {
    Data_Get_Struct(self, struct sDatabase, db);
    if (db->autocommit == 0) return Qfalse;
    else if (db->autocommit == 1) return Qtrue;
  }
  return Qnil;
}

static VALUE
Database_aset(VALUE self, VALUE key, VALUE value)
{
  struct sDatabase *db;
  int state;
  char *errmsg;
  VALUE errstr;

  Check_Type(key, T_STRING);

  if (rb_str_cmp(key, rb_str_new2("AutoCommit")) == 0) {
    Data_Get_Struct(self, struct sDatabase, db);
    if (RTEST(value)) {
      /* put autocommit on */
      if (db->autocommit == 0) {
        db->autocommit = 1;

        state = sqlite_exec(db->conn, "END TRANSACTION", NULL, NULL, &errmsg);
        if (state != SQLITE_OK) {
          errstr = rb_str_new2(errmsg); free(errmsg);
          rb_str_cat(errstr, "(", 1); rb_str_concat(errstr, rb_str_new2(sqliteErrStr(state))); rb_str_cat(errstr, ")", 1);
          rb_raise(eDatabaseError, STR2CSTR(errstr));
        }
      }
    } else {
      /* put autocommit off */
      if (db->autocommit == 1) {
        db->autocommit = 0;

        state = sqlite_exec(db->conn, "BEGIN TRANSACTION", NULL, NULL, &errmsg);
        if (state != SQLITE_OK) {
          errstr = rb_str_new2(errmsg); free(errmsg);
          rb_str_cat(errstr, "(", 1); rb_str_concat(errstr, rb_str_new2(sqliteErrStr(state))); rb_str_cat(errstr, ")", 1);
          rb_raise(eDatabaseError, STR2CSTR(errstr));
        }
      }
    }
  }
  return Qnil;
}


static VALUE
Database_disconnect(VALUE self)
{
  struct sDatabase *db;
  Data_Get_Struct(self, struct sDatabase, db);

  if (db->conn) {
    sqlite_close(db->conn);
    db->conn = NULL;
  }

  return Qnil;
}

static VALUE
Database_ping(VALUE self)
{
  return Qtrue;
}


static VALUE
Database_commit(VALUE self)
{
  VALUE errstr;
  struct sDatabase *db;
  int state;
  char *errmsg;

  Data_Get_Struct(self, struct sDatabase, db);

  if (db->autocommit == 0) { /* Autocommit is off */

    state = sqlite_exec(db->conn, "END TRANSACTION; BEGIN TRANSACTION", NULL, NULL, &errmsg);
    if (state != SQLITE_OK) {
      errstr = rb_str_new2(errmsg); free(errmsg);
      rb_str_cat(errstr, "(", 1); rb_str_concat(errstr, rb_str_new2(sqliteErrStr(state))); rb_str_cat(errstr, ")", 1);
      rb_raise(eDatabaseError, STR2CSTR(errstr));
    }

  } else if (db->autocommit == 1) { /* Autocommit is on */
    rb_warn("Warning: Commit ineffective while AutoCommit is on"); 
  }

  return Qnil;
}

static VALUE
Database_rollback(VALUE self)
{
  VALUE errstr;
  struct sDatabase *db;
  int state;
  char *errmsg;

  Data_Get_Struct(self, struct sDatabase, db);

  if (db->autocommit == 0) { /* Autocommit is off */

    state = sqlite_exec(db->conn, "ROLLBACK TRANSACTION; BEGIN TRANSACTION", NULL, NULL, &errmsg);
    if (state != SQLITE_OK) {
      errstr = rb_str_new2(errmsg); free(errmsg);
      rb_str_cat(errstr, "(", 1); rb_str_concat(errstr, rb_str_new2(sqliteErrStr(state))); rb_str_cat(errstr, ")", 1);
      rb_raise(eDatabaseError, STR2CSTR(errstr));
    }

  } else if (db->autocommit == 1) { /* Autocommit is on */
    rb_warn("Warning: Rollback ineffective while AutoCommit is on"); 
  }

  return Qnil;
}

static VALUE
Database_do(int argc, VALUE *argv, VALUE self)
{
  /* argv[0]         = stmt
   * argv[1..argc-1] = bindvars 
   */

  VALUE prs[3], sql, errstr;
  struct sDatabase *db;
  int state;
  char *errmsg;

  Data_Get_Struct(self, struct sDatabase, db);

  /* bind params to sql */
  prs[0] = self;
  prs[1] = argv[0];
  prs[2] = rb_ary_new4(argc-1, &argv[1]); 
  sql = rb_funcall2(self, rb_intern("bind"), 3, prs);

  state = sqlite_exec(db->conn, STR2CSTR(sql), NULL, NULL, &errmsg);
  if (state != SQLITE_OK) {
    errstr = rb_str_new2(errmsg); free(errmsg);
    rb_str_cat(errstr, "(", 1); rb_str_concat(errstr, rb_str_new2(sqliteErrStr(state))); rb_str_cat(errstr, ")", 1);
    rb_raise(eDatabaseError, STR2CSTR(errstr));
  }

  return Qnil;
}

static int tables_callback(void *pArg, int argc, char **argv, char **columnNames) {
  if (argv != 0 && argv[0] != 0) { 
    rb_ary_push(*(VALUE*)pArg, rb_str_new2(argv[0])); 
  }
  return 0;
}

static VALUE
Database_tables(VALUE self)
{
  VALUE errstr, arr;
  struct sDatabase *db;
  int state;
  char *errmsg;

  Data_Get_Struct(self, struct sDatabase, db);
  
  arr = rb_ary_new();

  state = sqlite_exec(db->conn, "SELECT name FROM sqlite_master WHERE type='table'", 
      &tables_callback, &arr, &errmsg); 

  if (state != SQLITE_OK) {
    errstr = rb_str_new2(errmsg); free(errmsg);
    rb_str_cat(errstr, "(", 1); rb_str_concat(errstr, rb_str_new2(sqliteErrStr(state))); rb_str_cat(errstr, ")", 1);
    rb_raise(eDatabaseError, STR2CSTR(errstr));
  }

  return arr;
}

static void statement_mark(void *p) {
  struct sStatement *sm = (struct sStatement*) p;
  
  rb_gc_mark(sm->conn);
  rb_gc_mark(sm->statement);
}

static void statement_free(void *p) {
  struct sStatement *sm = (struct sStatement*) p;

  if (sm->result) {
    sqlite_free_table(sm->result);
    sm->result = NULL;
  }

  free(p);
}

static VALUE
Database_prepare(VALUE self, VALUE stmt)
{
  VALUE statement;
  struct sStatement *sm;
  struct sDatabase *db;

  Data_Get_Struct(self, struct sDatabase, db);

  statement = Data_Make_Struct(cStatement, struct sStatement, statement_mark, statement_free, sm);
  rb_iv_set(statement, "@attr", rb_hash_new());
  rb_iv_set(statement, "@params", rb_ary_new()); 

  rb_iv_set(statement, "@col_names", Qnil);
  rb_iv_set(statement, "@rows", rb_ary_new());

  sm->conn = self; 
  sm->statement = stmt;
  sm->result = NULL;
  sm->nrow = -1;
  sm->ncolumn = -1;

  return statement;
}

static VALUE
Statement_bind_param(VALUE self, VALUE param, VALUE value, VALUE attribs) 
{
  if (FIXNUM_P(param)) {
    rb_ary_store(rb_iv_get(self, "@params"), FIX2INT(param)-1, value);  
  } else {
    rb_raise(eInterfaceError, "Only ? parameters supported");
  }
  return Qnil;
}

static VALUE
Statement_execute(VALUE self) 
{
  int state, i;
  char *errmsg;
  VALUE prs[3], sql, errstr, hash;
  struct sStatement *sm;
  struct sDatabase *db;

  Data_Get_Struct(self, struct sStatement, sm);
  Data_Get_Struct(sm->conn, struct sDatabase, db);

  /* bind params to sql */
  prs[0] = self;
  prs[1] = sm->statement;
  prs[2] = rb_iv_get(self, "@params"); 
  sql = rb_funcall2(self, rb_intern("bind"), 3, prs);

  rb_iv_set(sm->statement, "@params", rb_ary_new()); /* @params = [] */
  sm->row_index = 0;

  /* execute sql */
  state = sqlite_get_table(db->conn, STR2CSTR(sql), &sm->result, &sm->nrow, &sm->ncolumn, &errmsg); 
  if (state != SQLITE_OK) {
    errstr = rb_str_new2(errmsg); free(errmsg);
    rb_str_cat(errstr, "(", 1); rb_str_concat(errstr, rb_str_new2(sqliteErrStr(state))); rb_str_cat(errstr, ")", 1);
    rb_raise(eDatabaseError, STR2CSTR(errstr));
  }

  /* col_names */
  if (rb_iv_get(self, "@col_names") == Qnil) {
    rb_iv_set(self, "@col_names", rb_ary_new2(sm->ncolumn));

    for (i=0; i<sm->ncolumn;i++) {
      hash = rb_hash_new();
      if (sm->result[i] != NULL) {
        rb_hash_aset(hash, rb_str_new2("name"), rb_str_new2(sm->result[i]));
      }
      rb_ary_store(rb_iv_get(self, "@col_names"), i, hash);
    }
  }
  
  return Qnil; 
}

static VALUE
Statement_cancel(VALUE self)
{
  struct sStatement *sm;
  Data_Get_Struct(self, struct sStatement, sm);

  if (sm->result) {
    sqlite_free_table(sm->result);
    sm->result = NULL;
  }

  sm->nrow = -1;
  rb_iv_set(self, "@rows", rb_ary_new()); 
  rb_iv_set(self, "@params", rb_ary_new()); 

  return Qnil;
}


static VALUE
Statement_finish(VALUE self) 
{
  struct sStatement *sm;
  Data_Get_Struct(self, struct sStatement, sm);

  if (sm->result) {
    sqlite_free_table(sm->result);
    sm->result = NULL;
  }

  rb_iv_set(self, "@rows", Qnil); 
  rb_iv_set(self, "@params", Qnil); 

  return Qnil; 
} 

static VALUE
Statement_fetch(VALUE self) 
{
  struct sStatement *sm;
  int i, pos;
  VALUE rows;
  Data_Get_Struct(self, struct sStatement, sm);

  rows = rb_iv_get(self, "@rows"); 

  if (sm->row_index < sm->nrow) {
    pos = (sm->row_index+1)*sm->ncolumn;
    for (i=0; i<sm->ncolumn;i++) {
      rb_ary_store(rows, i, sm->result[pos+i] ? rb_str_new2(sm->result[pos+i]) : Qnil); 
    }
    sm->row_index += 1;
    return rows;
  } else {
    return Qnil; 
  }
}

static VALUE
Statement_fetch_scroll(VALUE self, VALUE direction, VALUE offset) 
{
  struct sStatement *sm;
  int i, pos, get_row, dir;
  VALUE rows;

  Data_Get_Struct(self, struct sStatement, sm);

  dir = NUM2INT(direction);

  switch (dir) {
    case SQL_FETCH_NEXT:        get_row = sm->row_index; break;
    case SQL_FETCH_PRIOR:       get_row = sm->row_index-1; break;
    case SQL_FETCH_FIRST:       get_row = 0; break;
    case SQL_FETCH_LAST:        get_row = sm->nrow-1; break;
    case SQL_FETCH_ABSOLUTE:    get_row = NUM2INT(offset); break;
    case SQL_FETCH_RELATIVE:    get_row = sm->row_index+NUM2INT(offset)-1; break;
    default:
      rb_raise(eNotSupportedError, "wrong direction");
  }

  if (get_row >= 0 && get_row < sm->nrow) {
    rows = rb_iv_get(self, "@rows"); 

    pos = (get_row+1)*sm->ncolumn;
    for (i=0; i<sm->ncolumn;i++) {
      rb_ary_store(rows, i, sm->result[pos+i] ? rb_str_new2(sm->result[pos+i]) : Qnil); 
    }

    /* position pointer */
    if (dir == SQL_FETCH_PRIOR) {
      sm->row_index = get_row;
    } else {
      sm->row_index = get_row + 1;
    }
 
    return rows;
  } else {
    if (get_row < 0) sm->row_index = 0; /* at the beginning => prev return nil */
    else if (get_row >= sm->nrow) sm->row_index = sm->nrow; /* at the end => next returns nil */
    return Qnil;
  }
}




static VALUE
Statement_column_info(VALUE self) 
{
  struct sStatement *sm;
  VALUE col_names;
  Data_Get_Struct(self, struct sStatement, sm);

  col_names = rb_iv_get(self, "@col_names");

  if (col_names == Qnil) {
    return rb_ary_new();
  } else {
    return col_names;
  }
}

static VALUE
Statement_rows(VALUE self) 
{
  struct sStatement *sm;
  Data_Get_Struct(self, struct sStatement, sm);

  if (sm->nrow != -1) {
    return INT2NUM(sm->nrow); 
  } else {
    return Qnil;
  }
}


/* Init */
void Init_SQLite() {
  mDBD              = rb_eval_string("DBI::DBD");
  cBaseDriver       = rb_eval_string("DBI::BaseDriver");
  cBaseDatabase     = rb_eval_string("DBI::BaseDatabase");
  cBaseStatement    = rb_eval_string("DBI::BaseStatement");
  eOperationalError = rb_eval_string("DBI::OperationalError"); 
  eDatabaseError    = rb_eval_string("DBI::DatabaseError"); 
  eInterfaceError   = rb_eval_string("DBI::InterfaceError"); 
  eNotSupportedError= rb_eval_string("DBI::NotSupportedError"); 

  mSQLite = rb_define_module_under(mDBD, "SQLite");

  /* Driver */
  cDriver    = rb_define_class_under(mSQLite, "Driver", cBaseDriver);
  rb_define_method(cDriver, "initialize", Driver_initialize, 0);
  rb_define_method(cDriver, "connect", Driver_connect, 4);
  rb_enable_super(cDriver, "initialize"); 

  /* Database */
  cDatabase  = rb_define_class_under(mSQLite, "Database", cBaseDatabase);
  rb_define_method(cDatabase, "disconnect", Database_disconnect, 0);
  rb_define_method(cDatabase, "prepare",    Database_prepare, 1);
  rb_define_method(cDatabase, "ping",       Database_ping, 0);
  rb_define_method(cDatabase, "do",         Database_do, -1);
  rb_define_method(cDatabase, "tables",     Database_tables, 0);
  rb_define_method(cDatabase, "commit",     Database_commit, 0);
  rb_define_method(cDatabase, "rollback",   Database_rollback, 0);
  rb_define_method(cDatabase, "[]",         Database_aref, 1);
  rb_define_method(cDatabase, "[]=",        Database_aset, 2);

  rb_include_module(cDatabase, rb_eval_string("DBI::SQL::BasicBind"));

  /* Statement */
  cStatement = rb_define_class_under(mSQLite, "Statement", cBaseStatement);
  rb_define_method(cStatement, "bind_param", Statement_bind_param, 3);
  rb_define_method(cStatement, "execute", Statement_execute, 0);
  rb_define_method(cStatement, "finish", Statement_finish, 0);
  rb_define_method(cStatement, "cancel", Statement_cancel, 0);
  rb_define_method(cStatement, "fetch", Statement_fetch, 0);
  rb_define_method(cStatement, "fetch_scroll", Statement_fetch_scroll, 2);
  rb_define_method(cStatement, "column_info", Statement_column_info, 0);
  rb_define_method(cStatement, "rows",    Statement_rows, 0);

  rb_include_module(cStatement, rb_eval_string("DBI::SQL::BasicBind"));
  rb_include_module(cStatement, rb_eval_string("DBI::SQL::BasicQuote"));
}


