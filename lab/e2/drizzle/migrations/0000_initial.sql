CREATE EXTENSION IF NOT EXISTS pg_trgm;
--> statement-breakpoint
CREATE EXTENSION IF NOT EXISTS unaccent;
--> statement-breakpoint
CREATE TABLE "audit_entries" (
	"id" integer PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "audit_entries_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START WITH 1 CACHE 1),
	"object_id" text NOT NULL,
	"action" text NOT NULL,
	"diff" jsonb NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "field_definitions" (
	"id" text PRIMARY KEY NOT NULL,
	"key" text NOT NULL,
	"value_type" text NOT NULL,
	CONSTRAINT "field_definitions_value_type_check" CHECK ("field_definitions"."value_type" IN ('text', 'number', 'boolean'))
);
--> statement-breakpoint
CREATE TABLE "object_field_values" (
	"object_id" text NOT NULL,
	"definition_id" text NOT NULL,
	"value" jsonb NOT NULL,
	CONSTRAINT "object_field_values_pk" PRIMARY KEY("object_id","definition_id")
);
--> statement-breakpoint
CREATE TABLE "object_tags" (
	"object_id" text NOT NULL,
	"tag_id" text NOT NULL,
	CONSTRAINT "object_tags_pk" PRIMARY KEY("object_id","tag_id")
);
--> statement-breakpoint
CREATE TABLE "objects" (
	"id" text PRIMARY KEY NOT NULL,
	"kind" text NOT NULL,
	"title" text NOT NULL,
	"version" integer DEFAULT 1 NOT NULL,
	"search_vector" "tsvector",
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "tags" (
	"id" text PRIMARY KEY NOT NULL,
	"name" text NOT NULL
);
--> statement-breakpoint
ALTER TABLE "audit_entries" ADD CONSTRAINT "audit_entries_object_id_objects_id_fk" FOREIGN KEY ("object_id") REFERENCES "public"."objects"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "object_field_values" ADD CONSTRAINT "object_field_values_object_id_objects_id_fk" FOREIGN KEY ("object_id") REFERENCES "public"."objects"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "object_field_values" ADD CONSTRAINT "object_field_values_definition_id_field_definitions_id_fk" FOREIGN KEY ("definition_id") REFERENCES "public"."field_definitions"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "object_tags" ADD CONSTRAINT "object_tags_object_id_objects_id_fk" FOREIGN KEY ("object_id") REFERENCES "public"."objects"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "object_tags" ADD CONSTRAINT "object_tags_tag_id_tags_id_fk" FOREIGN KEY ("tag_id") REFERENCES "public"."tags"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "field_definitions_key_idx" ON "field_definitions" USING btree ("key");--> statement-breakpoint
CREATE INDEX "objects_search_vector_gin_idx" ON "objects" USING gin ("search_vector");--> statement-breakpoint
CREATE INDEX "objects_title_trgm_idx" ON "objects" USING gin ("title" gin_trgm_ops);--> statement-breakpoint
CREATE UNIQUE INDEX "tags_name_idx" ON "tags" USING btree ("name");
