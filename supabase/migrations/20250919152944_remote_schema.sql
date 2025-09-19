

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE EXTENSION IF NOT EXISTS "pg_cron" WITH SCHEMA "pg_catalog";






CREATE SCHEMA IF NOT EXISTS "highlits";


ALTER SCHEMA "highlits" OWNER TO "postgres";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE SCHEMA IF NOT EXISTS "stripe";


ALTER SCHEMA "stripe" OWNER TO "postgres";


CREATE SCHEMA IF NOT EXISTS "util";


ALTER SCHEMA "util" OWNER TO "postgres";


CREATE EXTENSION IF NOT EXISTS "hstore" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgmq" WITH SCHEMA "pgmq";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "vector" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "wrappers" WITH SCHEMA "extensions";





SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "highlits"."highlights" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "readwise_id" integer NOT NULL,
    "external_id" "text",
    "book_id" "uuid",
    "user_book_id" integer NOT NULL,
    "text" "text" NOT NULL,
    "note" "text",
    "location" integer,
    "location_type" "text",
    "end_location" integer,
    "color" "text",
    "url" "text",
    "readwise_url" "text",
    "is_favorite" boolean DEFAULT false,
    "is_discard" boolean DEFAULT false,
    "is_deleted" boolean DEFAULT false,
    "highlighted_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "synced_at" timestamp with time zone DEFAULT "now"(),
    "embedding" "extensions"."halfvec"(1536)
);


ALTER TABLE "highlits"."highlights" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "highlits"."embedding_input"("doc" "highlits"."highlights") RETURNS "text"
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
begin
  return '# ' || doc.note || E'\n\n' || doc.text;
end;
$$;


ALTER FUNCTION "highlits"."embedding_input"("doc" "highlits"."highlights") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "highlits"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "highlits"."update_updated_at_column"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "util"."clear_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
declare
    clear_column text := TG_ARGV[0];
begin
    NEW := NEW #= hstore(clear_column, NULL);
    return NEW;
end;
$$;


ALTER FUNCTION "util"."clear_column"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "util"."invoke_edge_function"("name" "text", "body" "jsonb", "timeout_milliseconds" integer DEFAULT ((5 * 60) * 1000)) RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
declare
  headers_raw text;
  auth_header text;
begin
  -- If we're in a PostgREST session, reuse the request headers for authorization
  headers_raw := current_setting('request.headers', true);

  -- Only try to parse if headers are present
  auth_header := case
    when headers_raw is not null then
      (headers_raw::json->>'authorization')
    else
      null
  end;

  -- Perform async HTTP request to the edge function
  perform net.http_post(
    url => util.project_url() || '/functions/v1/' || name,
    headers => jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', auth_header
    ),
    body => body,
    timeout_milliseconds => timeout_milliseconds
  );
end;
$$;


ALTER FUNCTION "util"."invoke_edge_function"("name" "text", "body" "jsonb", "timeout_milliseconds" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "util"."process_embeddings"("batch_size" integer DEFAULT 10, "max_requests" integer DEFAULT 10, "timeout_milliseconds" integer DEFAULT ((5 * 60) * 1000)) RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
declare
  job_batches jsonb[];
  batch jsonb;
begin
  with
    -- First get jobs and assign batch numbers
    numbered_jobs as (
      select
        message || jsonb_build_object('jobId', msg_id) as job_info,
        (row_number() over (order by 1) - 1) / batch_size as batch_num
      from pgmq.read(
        queue_name => 'embedding_jobs',
        vt => timeout_milliseconds / 1000,
        qty => max_requests * batch_size
      )
    ),
    -- Then group jobs into batches
    batched_jobs as (
      select
        jsonb_agg(job_info) as batch_array,
        batch_num
      from numbered_jobs
      group by batch_num
    )
  -- Finally aggregate all batches into array
  select array_agg(batch_array)
  from batched_jobs
  into job_batches;

  -- Invoke the embed edge function for each batch
  foreach batch in array job_batches loop
    perform util.invoke_edge_function(
      name => 'embed',
      body => batch,
      timeout_milliseconds => timeout_milliseconds
    );
  end loop;
end;
$$;


ALTER FUNCTION "util"."process_embeddings"("batch_size" integer, "max_requests" integer, "timeout_milliseconds" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "util"."project_url"() RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
declare
  secret_value text;
begin
  -- Retrieve the project URL from Vault
  select decrypted_secret into secret_value from vault.decrypted_secrets where name = 'project_url';
  return secret_value;
end;
$$;


ALTER FUNCTION "util"."project_url"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "util"."queue_embeddings"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  content_function text = TG_ARGV[0];
  embedding_column text = TG_ARGV[1];
begin
  perform pgmq.send(
    queue_name => 'embedding_jobs',
    msg => jsonb_build_object(
      'id', NEW.id,
      'schema', TG_TABLE_SCHEMA,
      'table', TG_TABLE_NAME,
      'contentFunction', content_function,
      'embeddingColumn', embedding_column
    )
  );
  return NEW;
end;
$$;


ALTER FUNCTION "util"."queue_embeddings"() OWNER TO "postgres";


CREATE FOREIGN DATA WRAPPER "stripe_wrapper" HANDLER "extensions"."stripe_fdw_handler" VALIDATOR "extensions"."stripe_fdw_validator";




CREATE SERVER "stripe_wrapper_server" FOREIGN DATA WRAPPER "stripe_wrapper" OPTIONS (
    "api_key_id" 'c1f245b0-6b22-41a8-b88f-a6f0463e095d',
    "api_url" 'https://api.stripe.com/v1/'
);


ALTER SERVER "stripe_wrapper_server" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "highlits"."book_tags" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "book_id" "uuid",
    "tag_name" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "highlits"."book_tags" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "highlits"."books" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_book_id" integer NOT NULL,
    "external_id" "text",
    "title" "text" NOT NULL,
    "author" "text",
    "readable_title" "text",
    "source" "text",
    "cover_image_url" "text",
    "unique_url" "text",
    "category" "text",
    "document_note" "text",
    "summary" "text",
    "readwise_url" "text",
    "source_url" "text",
    "asin" "text",
    "is_deleted" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "synced_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "highlits"."books" OWNER TO "postgres";


CREATE OR REPLACE VIEW "highlits"."books_with_highlight_counts" AS
 SELECT "b"."id",
    "b"."user_book_id",
    "b"."external_id",
    "b"."title",
    "b"."author",
    "b"."readable_title",
    "b"."source",
    "b"."cover_image_url",
    "b"."unique_url",
    "b"."category",
    "b"."document_note",
    "b"."summary",
    "b"."readwise_url",
    "b"."source_url",
    "b"."asin",
    "b"."is_deleted",
    "b"."created_at",
    "b"."updated_at",
    "b"."synced_at",
    COALESCE("h"."highlight_count", (0)::bigint) AS "highlight_count",
    COALESCE("h"."favorite_count", (0)::bigint) AS "favorite_count"
   FROM ("highlits"."books" "b"
     LEFT JOIN ( SELECT "highlights"."book_id",
            "count"(*) AS "highlight_count",
            "count"(
                CASE
                    WHEN "highlights"."is_favorite" THEN 1
                    ELSE NULL::integer
                END) AS "favorite_count"
           FROM "highlits"."highlights"
          WHERE ("highlights"."is_deleted" = false)
          GROUP BY "highlights"."book_id") "h" ON (("b"."id" = "h"."book_id")))
  WHERE ("b"."is_deleted" = false);


ALTER VIEW "highlits"."books_with_highlight_counts" OWNER TO "postgres";


CREATE OR REPLACE VIEW "highlits"."favorite_highlights" AS
 SELECT "h"."id",
    "h"."readwise_id",
    "h"."external_id",
    "h"."book_id",
    "h"."user_book_id",
    "h"."text",
    "h"."note",
    "h"."location",
    "h"."location_type",
    "h"."end_location",
    "h"."color",
    "h"."url",
    "h"."readwise_url",
    "h"."is_favorite",
    "h"."is_discard",
    "h"."is_deleted",
    "h"."highlighted_at",
    "h"."created_at",
    "h"."updated_at",
    "h"."synced_at",
    "b"."title" AS "book_title",
    "b"."author" AS "book_author",
    "b"."source" AS "book_source"
   FROM ("highlits"."highlights" "h"
     JOIN "highlits"."books" "b" ON (("h"."book_id" = "b"."id")))
  WHERE (("h"."is_favorite" = true) AND ("h"."is_deleted" = false) AND ("b"."is_deleted" = false))
  ORDER BY "h"."highlighted_at" DESC;


ALTER VIEW "highlits"."favorite_highlights" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "highlits"."highlight_tags" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "highlight_id" "uuid",
    "tag_name" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "highlits"."highlight_tags" OWNER TO "postgres";


CREATE OR REPLACE VIEW "highlits"."recent_highlights" AS
 SELECT "h"."id",
    "h"."readwise_id",
    "h"."external_id",
    "h"."book_id",
    "h"."user_book_id",
    "h"."text",
    "h"."note",
    "h"."location",
    "h"."location_type",
    "h"."end_location",
    "h"."color",
    "h"."url",
    "h"."readwise_url",
    "h"."is_favorite",
    "h"."is_discard",
    "h"."is_deleted",
    "h"."highlighted_at",
    "h"."created_at",
    "h"."updated_at",
    "h"."synced_at",
    "b"."title" AS "book_title",
    "b"."author" AS "book_author",
    "b"."source" AS "book_source"
   FROM ("highlits"."highlights" "h"
     JOIN "highlits"."books" "b" ON (("h"."book_id" = "b"."id")))
  WHERE (("h"."is_deleted" = false) AND ("b"."is_deleted" = false))
  ORDER BY "h"."highlighted_at" DESC;


ALTER VIEW "highlits"."recent_highlights" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "highlits"."sync_log" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "sync_type" "text" NOT NULL,
    "updated_after" timestamp with time zone,
    "books_synced" integer DEFAULT 0,
    "highlights_synced" integer DEFAULT 0,
    "errors" "text"[],
    "started_at" timestamp with time zone DEFAULT "now"(),
    "completed_at" timestamp with time zone,
    "status" "text" DEFAULT 'in_progress'::"text"
);


ALTER TABLE "highlits"."sync_log" OWNER TO "postgres";


CREATE FOREIGN TABLE "stripe"."accounts" (
    "id" "text",
    "business_type" "text",
    "country" "text",
    "email" "text",
    "type" "text",
    "created" timestamp without time zone,
    "attrs" "jsonb"
)
SERVER "stripe_wrapper_server"
OPTIONS (
    "id" '17623',
    "object" 'accounts',
    "rowid_column" 'id',
    "schema" 'stripe'
);


ALTER FOREIGN TABLE "stripe"."accounts" OWNER TO "postgres";


CREATE FOREIGN TABLE "stripe"."balance" (
    "balance_type" "text",
    "amount" bigint,
    "currency" "text",
    "attrs" "jsonb"
)
SERVER "stripe_wrapper_server"
OPTIONS (
    "id" '17644',
    "object" 'balance',
    "rowid_column" 'id',
    "schema" 'stripe'
);


ALTER FOREIGN TABLE "stripe"."balance" OWNER TO "postgres";


CREATE FOREIGN TABLE "stripe"."balance_transactions" (
    "id" "text",
    "amount" bigint,
    "currency" "text",
    "description" "text",
    "fee" bigint,
    "net" bigint,
    "status" "text",
    "type" "text",
    "created" timestamp without time zone,
    "attrs" "jsonb"
)
SERVER "stripe_wrapper_server"
OPTIONS (
    "id" '17635',
    "object" 'balance_transactions',
    "rowid_column" 'id',
    "schema" 'stripe'
);


ALTER FOREIGN TABLE "stripe"."balance_transactions" OWNER TO "postgres";


CREATE FOREIGN TABLE "stripe"."billing_meters" (
    "id" "text",
    "display_name" "text",
    "event_name" "text",
    "event_time_window" "text",
    "status" "text",
    "attrs" "jsonb"
)
SERVER "stripe_wrapper_server"
OPTIONS (
    "id" '17641',
    "object" 'billing/meters',
    "rowid_column" 'id',
    "schema" 'stripe'
);


ALTER FOREIGN TABLE "stripe"."billing_meters" OWNER TO "postgres";


CREATE FOREIGN TABLE "stripe"."charges" (
    "id" "text",
    "amount" bigint,
    "currency" "text",
    "customer" "text",
    "description" "text",
    "invoice" "text",
    "payment_intent" "text",
    "status" "text",
    "created" timestamp without time zone,
    "attrs" "jsonb"
)
SERVER "stripe_wrapper_server"
OPTIONS (
    "id" '17653',
    "object" 'charges',
    "rowid_column" 'id',
    "schema" 'stripe'
);


ALTER FOREIGN TABLE "stripe"."charges" OWNER TO "postgres";


CREATE FOREIGN TABLE "stripe"."checkout_sessions" (
    "id" "text",
    "customer" "text",
    "payment_intent" "text",
    "subscription" "text",
    "created" timestamp without time zone,
    "attrs" "jsonb"
)
SERVER "stripe_wrapper_server"
OPTIONS (
    "id" '17632',
    "object" 'checkout/sessions',
    "rowid_column" 'id',
    "schema" 'stripe'
);


ALTER FOREIGN TABLE "stripe"."checkout_sessions" OWNER TO "postgres";


CREATE FOREIGN TABLE "stripe"."customers" (
    "id" "text",
    "email" "text",
    "name" "text",
    "description" "text",
    "created" timestamp without time zone,
    "attrs" "jsonb"
)
SERVER "stripe_wrapper_server"
OPTIONS (
    "id" '17650',
    "object" 'customers',
    "rowid_column" 'id',
    "schema" 'stripe'
);


ALTER FOREIGN TABLE "stripe"."customers" OWNER TO "postgres";


CREATE FOREIGN TABLE "stripe"."disputes" (
    "id" "text",
    "amount" bigint,
    "currency" "text",
    "charge" "text",
    "payment_intent" "text",
    "reason" "text",
    "status" "text",
    "created" timestamp without time zone,
    "attrs" "jsonb"
)
SERVER "stripe_wrapper_server"
OPTIONS (
    "id" '17683',
    "object" 'disputes',
    "rowid_column" 'id',
    "schema" 'stripe'
);


ALTER FOREIGN TABLE "stripe"."disputes" OWNER TO "postgres";


CREATE FOREIGN TABLE "stripe"."events" (
    "id" "text",
    "type" "text",
    "api_version" "text",
    "created" timestamp without time zone,
    "attrs" "jsonb"
)
SERVER "stripe_wrapper_server"
OPTIONS (
    "id" '17674',
    "object" 'events',
    "rowid_column" 'id',
    "schema" 'stripe'
);


ALTER FOREIGN TABLE "stripe"."events" OWNER TO "postgres";


CREATE FOREIGN TABLE "stripe"."file_links" (
    "id" "text",
    "file" "text",
    "url" "text",
    "created" timestamp without time zone,
    "expired" boolean,
    "expires_at" timestamp without time zone,
    "attrs" "jsonb"
)
SERVER "stripe_wrapper_server"
OPTIONS (
    "id" '17677',
    "object" 'file_links',
    "rowid_column" 'id',
    "schema" 'stripe'
);


ALTER FOREIGN TABLE "stripe"."file_links" OWNER TO "postgres";


CREATE FOREIGN TABLE "stripe"."files" (
    "id" "text",
    "filename" "text",
    "purpose" "text",
    "title" "text",
    "size" bigint,
    "type" "text",
    "url" "text",
    "created" timestamp without time zone,
    "expires_at" timestamp without time zone,
    "attrs" "jsonb"
)
SERVER "stripe_wrapper_server"
OPTIONS (
    "id" '17647',
    "object" 'files',
    "rowid_column" 'id',
    "schema" 'stripe'
);


ALTER FOREIGN TABLE "stripe"."files" OWNER TO "postgres";


CREATE FOREIGN TABLE "stripe"."invoices" (
    "id" "text",
    "customer" "text",
    "subscription" "text",
    "status" "text",
    "total" bigint,
    "currency" "text",
    "period_start" timestamp without time zone,
    "period_end" timestamp without time zone,
    "attrs" "jsonb"
)
SERVER "stripe_wrapper_server"
OPTIONS (
    "id" '17620',
    "object" 'invoices',
    "rowid_column" 'id',
    "schema" 'stripe'
);


ALTER FOREIGN TABLE "stripe"."invoices" OWNER TO "postgres";


CREATE FOREIGN TABLE "stripe"."mandates" (
    "id" "text",
    "payment_method" "text",
    "status" "text",
    "type" "text",
    "attrs" "jsonb"
)
SERVER "stripe_wrapper_server"
OPTIONS (
    "id" '17638',
    "object" 'mandates',
    "rowid_column" 'id',
    "schema" 'stripe'
);


ALTER FOREIGN TABLE "stripe"."mandates" OWNER TO "postgres";


CREATE FOREIGN TABLE "stripe"."payment_intents" (
    "id" "text",
    "customer" "text",
    "amount" bigint,
    "currency" "text",
    "payment_method" "text",
    "created" timestamp without time zone,
    "attrs" "jsonb"
)
SERVER "stripe_wrapper_server"
OPTIONS (
    "id" '17659',
    "object" 'payment_intents',
    "rowid_column" 'id',
    "schema" 'stripe'
);


ALTER FOREIGN TABLE "stripe"."payment_intents" OWNER TO "postgres";


CREATE FOREIGN TABLE "stripe"."payouts" (
    "id" "text",
    "amount" bigint,
    "currency" "text",
    "arrival_date" timestamp without time zone,
    "description" "text",
    "statement_descriptor" "text",
    "status" "text",
    "created" timestamp without time zone,
    "attrs" "jsonb"
)
SERVER "stripe_wrapper_server"
OPTIONS (
    "id" '17689',
    "object" 'payouts',
    "rowid_column" 'id',
    "schema" 'stripe'
);


ALTER FOREIGN TABLE "stripe"."payouts" OWNER TO "postgres";


CREATE FOREIGN TABLE "stripe"."prices" (
    "id" "text",
    "active" boolean,
    "currency" "text",
    "product" "text",
    "unit_amount" bigint,
    "type" "text",
    "created" timestamp without time zone,
    "attrs" "jsonb"
)
SERVER "stripe_wrapper_server"
OPTIONS (
    "id" '17665',
    "object" 'prices',
    "rowid_column" 'id',
    "schema" 'stripe'
);


ALTER FOREIGN TABLE "stripe"."prices" OWNER TO "postgres";


CREATE FOREIGN TABLE "stripe"."products" (
    "id" "text",
    "name" "text",
    "active" boolean,
    "default_price" "text",
    "description" "text",
    "created" timestamp without time zone,
    "updated" timestamp without time zone,
    "attrs" "jsonb"
)
SERVER "stripe_wrapper_server"
OPTIONS (
    "id" '17686',
    "object" 'products',
    "rowid_column" 'id',
    "schema" 'stripe'
);


ALTER FOREIGN TABLE "stripe"."products" OWNER TO "postgres";


CREATE FOREIGN TABLE "stripe"."refunds" (
    "id" "text",
    "amount" bigint,
    "currency" "text",
    "charge" "text",
    "payment_intent" "text",
    "reason" "text",
    "status" "text",
    "created" timestamp without time zone,
    "attrs" "jsonb"
)
SERVER "stripe_wrapper_server"
OPTIONS (
    "id" '17626',
    "object" 'refunds',
    "rowid_column" 'id',
    "schema" 'stripe'
);


ALTER FOREIGN TABLE "stripe"."refunds" OWNER TO "postgres";


CREATE FOREIGN TABLE "stripe"."setup_attempts" (
    "id" "text",
    "application" "text",
    "customer" "text",
    "on_behalf_of" "text",
    "payment_method" "text",
    "setup_intent" "text",
    "status" "text",
    "usage" "text",
    "created" timestamp without time zone,
    "attrs" "jsonb"
)
SERVER "stripe_wrapper_server"
OPTIONS (
    "id" '17656',
    "object" 'setup_attempts',
    "rowid_column" 'id',
    "schema" 'stripe'
);


ALTER FOREIGN TABLE "stripe"."setup_attempts" OWNER TO "postgres";


CREATE FOREIGN TABLE "stripe"."setup_intents" (
    "id" "text",
    "client_secret" "text",
    "customer" "text",
    "description" "text",
    "payment_method" "text",
    "status" "text",
    "usage" "text",
    "created" timestamp without time zone,
    "attrs" "jsonb"
)
SERVER "stripe_wrapper_server"
OPTIONS (
    "id" '17671',
    "object" 'setup_intents',
    "rowid_column" 'id',
    "schema" 'stripe'
);


ALTER FOREIGN TABLE "stripe"."setup_intents" OWNER TO "postgres";


CREATE FOREIGN TABLE "stripe"."subscriptions" (
    "id" "text",
    "customer" "text",
    "currency" "text",
    "current_period_start" timestamp without time zone,
    "current_period_end" timestamp without time zone,
    "attrs" "jsonb"
)
SERVER "stripe_wrapper_server"
OPTIONS (
    "id" '17680',
    "object" 'subscriptions',
    "rowid_column" 'id',
    "schema" 'stripe'
);


ALTER FOREIGN TABLE "stripe"."subscriptions" OWNER TO "postgres";


CREATE FOREIGN TABLE "stripe"."tokens" (
    "id" "text",
    "type" "text",
    "client_ip" "text",
    "used" boolean,
    "livemode" boolean,
    "created" timestamp without time zone,
    "attrs" "jsonb"
)
SERVER "stripe_wrapper_server"
OPTIONS (
    "id" '17668',
    "object" 'tokens',
    "rowid_column" 'id',
    "schema" 'stripe'
);


ALTER FOREIGN TABLE "stripe"."tokens" OWNER TO "postgres";


CREATE FOREIGN TABLE "stripe"."topups" (
    "id" "text",
    "amount" bigint,
    "currency" "text",
    "description" "text",
    "status" "text",
    "created" timestamp without time zone,
    "attrs" "jsonb"
)
SERVER "stripe_wrapper_server"
OPTIONS (
    "id" '17662',
    "object" 'topups',
    "rowid_column" 'id',
    "schema" 'stripe'
);


ALTER FOREIGN TABLE "stripe"."topups" OWNER TO "postgres";


CREATE FOREIGN TABLE "stripe"."transfers" (
    "id" "text",
    "amount" bigint,
    "currency" "text",
    "description" "text",
    "destination" "text",
    "created" timestamp without time zone,
    "attrs" "jsonb"
)
SERVER "stripe_wrapper_server"
OPTIONS (
    "id" '17629',
    "object" 'transfers',
    "rowid_column" 'id',
    "schema" 'stripe'
);


ALTER FOREIGN TABLE "stripe"."transfers" OWNER TO "postgres";


ALTER TABLE ONLY "highlits"."book_tags"
    ADD CONSTRAINT "book_tags_book_id_tag_name_key" UNIQUE ("book_id", "tag_name");



ALTER TABLE ONLY "highlits"."book_tags"
    ADD CONSTRAINT "book_tags_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "highlits"."books"
    ADD CONSTRAINT "books_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "highlits"."books"
    ADD CONSTRAINT "books_user_book_id_key" UNIQUE ("user_book_id");



ALTER TABLE ONLY "highlits"."highlight_tags"
    ADD CONSTRAINT "highlight_tags_highlight_id_tag_name_key" UNIQUE ("highlight_id", "tag_name");



ALTER TABLE ONLY "highlits"."highlight_tags"
    ADD CONSTRAINT "highlight_tags_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "highlits"."highlights"
    ADD CONSTRAINT "highlights_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "highlits"."highlights"
    ADD CONSTRAINT "highlights_readwise_id_key" UNIQUE ("readwise_id");



ALTER TABLE ONLY "highlits"."sync_log"
    ADD CONSTRAINT "sync_log_pkey" PRIMARY KEY ("id");



CREATE INDEX "idx_book_tags_book_id" ON "highlits"."book_tags" USING "btree" ("book_id");



CREATE INDEX "idx_book_tags_tag_name" ON "highlits"."book_tags" USING "btree" ("tag_name");



CREATE INDEX "idx_books_category" ON "highlits"."books" USING "btree" ("category");



CREATE INDEX "idx_books_is_deleted" ON "highlits"."books" USING "btree" ("is_deleted");



CREATE INDEX "idx_books_source" ON "highlits"."books" USING "btree" ("source");



CREATE INDEX "idx_books_updated_at" ON "highlits"."books" USING "btree" ("updated_at");



CREATE INDEX "idx_books_user_book_id" ON "highlits"."books" USING "btree" ("user_book_id");



CREATE INDEX "idx_highlight_tags_highlight_id" ON "highlits"."highlight_tags" USING "btree" ("highlight_id");



CREATE INDEX "idx_highlight_tags_tag_name" ON "highlits"."highlight_tags" USING "btree" ("tag_name");



CREATE INDEX "idx_highlights_book_id" ON "highlits"."highlights" USING "btree" ("book_id");



CREATE INDEX "idx_highlights_color" ON "highlits"."highlights" USING "btree" ("color");



CREATE INDEX "idx_highlights_highlighted_at" ON "highlits"."highlights" USING "btree" ("highlighted_at");



CREATE INDEX "idx_highlights_is_deleted" ON "highlits"."highlights" USING "btree" ("is_deleted");



CREATE INDEX "idx_highlights_is_favorite" ON "highlits"."highlights" USING "btree" ("is_favorite");



CREATE INDEX "idx_highlights_readwise_id" ON "highlits"."highlights" USING "btree" ("readwise_id");



CREATE INDEX "idx_highlights_updated_at" ON "highlits"."highlights" USING "btree" ("updated_at");



CREATE INDEX "idx_highlights_user_book_id" ON "highlits"."highlights" USING "btree" ("user_book_id");



CREATE INDEX "idx_sync_log_started_at" ON "highlits"."sync_log" USING "btree" ("started_at");



CREATE INDEX "idx_sync_log_status" ON "highlits"."sync_log" USING "btree" ("status");



CREATE OR REPLACE TRIGGER "embed_documents_on_insert" AFTER INSERT ON "highlits"."highlights" FOR EACH ROW EXECUTE FUNCTION "util"."queue_embeddings"('embedding_input', 'embedding');



CREATE OR REPLACE TRIGGER "embed_documents_on_update" AFTER UPDATE OF "note", "text" ON "highlits"."highlights" FOR EACH ROW EXECUTE FUNCTION "util"."queue_embeddings"('embedding_input', 'embedding');



CREATE OR REPLACE TRIGGER "update_books_updated_at" BEFORE UPDATE ON "highlits"."books" FOR EACH ROW EXECUTE FUNCTION "highlits"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_highlights_updated_at" BEFORE UPDATE ON "highlits"."highlights" FOR EACH ROW EXECUTE FUNCTION "highlits"."update_updated_at_column"();



ALTER TABLE ONLY "highlits"."book_tags"
    ADD CONSTRAINT "book_tags_book_id_fkey" FOREIGN KEY ("book_id") REFERENCES "highlits"."books"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "highlits"."highlight_tags"
    ADD CONSTRAINT "highlight_tags_highlight_id_fkey" FOREIGN KEY ("highlight_id") REFERENCES "highlits"."highlights"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "highlits"."highlights"
    ADD CONSTRAINT "highlights_book_id_fkey" FOREIGN KEY ("book_id") REFERENCES "highlits"."books"("id") ON DELETE CASCADE;





ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";





GRANT USAGE ON SCHEMA "highlits" TO "anon";
GRANT USAGE ON SCHEMA "highlits" TO "authenticated";
GRANT USAGE ON SCHEMA "highlits" TO "service_role";



GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";













































































































































































































































































































































































































































































































































































































































































































































































































































GRANT ALL ON TABLE "highlits"."highlights" TO "anon";
GRANT ALL ON TABLE "highlits"."highlights" TO "authenticated";
GRANT ALL ON TABLE "highlits"."highlights" TO "service_role";



GRANT ALL ON FUNCTION "highlits"."embedding_input"("doc" "highlits"."highlights") TO "anon";
GRANT ALL ON FUNCTION "highlits"."embedding_input"("doc" "highlits"."highlights") TO "authenticated";
GRANT ALL ON FUNCTION "highlits"."embedding_input"("doc" "highlits"."highlights") TO "service_role";



GRANT ALL ON FUNCTION "highlits"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "highlits"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "highlits"."update_updated_at_column"() TO "service_role";







































GRANT ALL ON TABLE "highlits"."book_tags" TO "anon";
GRANT ALL ON TABLE "highlits"."book_tags" TO "authenticated";
GRANT ALL ON TABLE "highlits"."book_tags" TO "service_role";



GRANT ALL ON TABLE "highlits"."books" TO "anon";
GRANT ALL ON TABLE "highlits"."books" TO "authenticated";
GRANT ALL ON TABLE "highlits"."books" TO "service_role";



GRANT ALL ON TABLE "highlits"."books_with_highlight_counts" TO "anon";
GRANT ALL ON TABLE "highlits"."books_with_highlight_counts" TO "authenticated";
GRANT ALL ON TABLE "highlits"."books_with_highlight_counts" TO "service_role";



GRANT ALL ON TABLE "highlits"."favorite_highlights" TO "anon";
GRANT ALL ON TABLE "highlits"."favorite_highlights" TO "authenticated";
GRANT ALL ON TABLE "highlits"."favorite_highlights" TO "service_role";



GRANT ALL ON TABLE "highlits"."highlight_tags" TO "anon";
GRANT ALL ON TABLE "highlits"."highlight_tags" TO "authenticated";
GRANT ALL ON TABLE "highlits"."highlight_tags" TO "service_role";



GRANT ALL ON TABLE "highlits"."recent_highlights" TO "anon";
GRANT ALL ON TABLE "highlits"."recent_highlights" TO "authenticated";
GRANT ALL ON TABLE "highlits"."recent_highlights" TO "service_role";



GRANT ALL ON TABLE "highlits"."sync_log" TO "anon";
GRANT ALL ON TABLE "highlits"."sync_log" TO "authenticated";
GRANT ALL ON TABLE "highlits"."sync_log" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "highlits" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "highlits" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "highlits" GRANT ALL ON SEQUENCES TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "highlits" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "highlits" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "highlits" GRANT ALL ON FUNCTIONS TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "highlits" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "highlits" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "highlits" GRANT ALL ON TABLES TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";






























RESET ALL;
