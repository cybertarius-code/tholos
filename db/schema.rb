# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_25_100000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.bigint "household_id", null: false
    t.string "name", null: false
    t.string "kind", null: false
    t.string "currency", limit: 3, null: false
    t.bigint "opening_balance_cents", default: 0, null: false
    t.date "opening_date", null: false
    t.string "status", default: "open", null: false
    t.boolean "include_in_net_worth", default: true, null: false
    t.text "notes"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["household_id", "status"], name: "index_accounts_on_household_id_and_status"
    t.index ["id", "currency"], name: "index_accounts_on_id_and_currency", unique: true
    t.index ["id", "household_id"], name: "index_accounts_on_id_and_household_id", unique: true
    t.check_constraint "kind::text = ANY (ARRAY['checking'::character varying, 'savings'::character varying, 'cash'::character varying, 'ewallet'::character varying, 'credit_card'::character varying, 'loan'::character varying, 'investment'::character varying, 'other'::character varying]::text[])", name: "accounts_kind_check"
    t.check_constraint "status::text = ANY (ARRAY['open'::character varying, 'closed'::character varying]::text[])", name: "accounts_status_check"
  end

  create_table "categories", force: :cascade do |t|
    t.bigint "household_id", null: false
    t.bigint "parent_id"
    t.string "name", null: false
    t.string "kind", null: false
    t.string "report_group"
    t.string "color", null: false
    t.string "icon", null: false
    t.integer "position", default: 0, null: false
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "household_id, parent_id, lower((name)::text)", name: "index_categories_on_household_parent_lower_name", unique: true, nulls_not_distinct: true
    t.index ["household_id", "kind", "position"], name: "index_categories_on_household_id_and_kind_and_position"
    t.index ["id", "household_id"], name: "index_categories_on_id_and_household_id", unique: true
    t.index ["id", "kind"], name: "index_categories_on_id_and_kind", unique: true
    t.index ["parent_id"], name: "index_categories_on_parent_id"
    t.check_constraint "kind::text = ANY (ARRAY['expense'::character varying, 'income'::character varying]::text[])", name: "categories_kind_check"
    t.check_constraint "parent_id IS NULL OR report_group IS NULL", name: "categories_report_group_only_on_parents"
    t.check_constraint "report_group IS NULL OR (report_group::text = ANY (ARRAY['essentials'::character varying, 'lifestyle'::character varying, 'growth'::character varying, 'work'::character varying, 'finance'::character varying, 'other'::character varying]::text[]))", name: "categories_report_group_check"
  end

  create_table "households", force: :cascade do |t|
    t.string "name", null: false
    t.string "base_currency", limit: 3, default: "EUR", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "import_rows", force: :cascade do |t|
    t.bigint "import_id", null: false
    t.integer "line", null: false
    t.date "date", null: false
    t.string "concept", null: false
    t.bigint "amount_cents", null: false
    t.bigint "balance_cents", null: false
    t.string "import_ref", null: false
    t.string "proposal", default: "none", null: false
    t.boolean "skipped", default: false, null: false
    t.bigint "category_id"
    t.text "commit_error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "counter_account_id"
    t.bigint "matched_transaction_id"
    t.date "original_date"
    t.bigint "original_amount_cents"
    t.string "original_concept"
    t.index ["category_id"], name: "index_import_rows_on_category_id"
    t.index ["counter_account_id"], name: "index_import_rows_on_counter_account_id"
    t.index ["import_id", "line"], name: "index_import_rows_on_import_id_and_line", unique: true
    t.index ["matched_transaction_id"], name: "index_import_rows_on_matched_transaction_id"
    t.check_constraint "(skipped::integer + num_nonnulls(category_id, counter_account_id, matched_transaction_id)) <= 1", name: "import_rows_una_decision"
    t.check_constraint "proposal::text = ANY (ARRAY['none'::character varying, 'duplicate'::character varying, 'before_cutoff'::character varying]::text[])", name: "import_rows_proposal_check"
  end

  create_table "imports", force: :cascade do |t|
    t.bigint "household_id", null: false
    t.bigint "account_id", null: false
    t.string "status", default: "staged", null: false
    t.string "filename"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_imports_on_account_id"
    t.index ["household_id"], name: "index_imports_on_household_id"
    t.check_constraint "status::text = ANY (ARRAY['staged'::character varying, 'confirmed'::character varying]::text[])", name: "imports_status_check"
  end

  create_table "memberships", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "household_id", null: false
    t.string "role", default: "owner", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["household_id"], name: "index_memberships_on_household_id"
    t.index ["user_id", "household_id"], name: "index_memberships_on_user_id_and_household_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "transactions", force: :cascade do |t|
    t.bigint "household_id", null: false
    t.bigint "account_id", null: false
    t.bigint "category_id"
    t.bigint "amount_cents", null: false
    t.string "currency", limit: 3, null: false
    t.date "date", null: false
    t.string "status", default: "cleared", null: false
    t.string "payee"
    t.text "notes"
    t.bigint "transfer_id"
    t.boolean "adjustment", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "import_ref"
    t.index "transfer_id, ((amount_cents > 0))", name: "transactions_un_lado_por_signo", unique: true, where: "(transfer_id IS NOT NULL)"
    t.index ["account_id", "date"], name: "index_transactions_on_account_id_and_date"
    t.index ["category_id", "date"], name: "index_transactions_on_category_id_and_date"
    t.index ["household_id", "date"], name: "index_transactions_on_household_id_and_date"
    t.index ["import_ref"], name: "index_transactions_on_import_ref", unique: true
    t.check_constraint "amount_cents <> 0", name: "transactions_importe_no_cero"
    t.check_constraint "num_nonnulls(transfer_id, NULLIF(adjustment, false), category_id) <= 1", name: "transactions_un_solo_tipo"
    t.check_constraint "status::text = ANY (ARRAY['scheduled'::character varying, 'pending'::character varying, 'cleared'::character varying]::text[])", name: "transactions_status_check"
  end

  create_table "transfers", force: :cascade do |t|
    t.bigint "household_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["household_id"], name: "index_transfers_on_household_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "accounts", "households"
  add_foreign_key "categories", "categories", column: ["parent_id", "kind"], primary_key: ["id", "kind"], name: "categories_parent_kind_fk", on_delete: :restrict
  add_foreign_key "categories", "households"
  add_foreign_key "import_rows", "accounts", column: "counter_account_id", on_delete: :nullify
  add_foreign_key "import_rows", "categories", on_delete: :nullify
  add_foreign_key "import_rows", "imports", on_delete: :cascade
  add_foreign_key "import_rows", "transactions", column: "matched_transaction_id", on_delete: :nullify
  add_foreign_key "imports", "accounts", column: ["account_id", "household_id"], primary_key: ["id", "household_id"], name: "imports_account_household_fk", on_delete: :restrict
  add_foreign_key "imports", "households"
  add_foreign_key "memberships", "households"
  add_foreign_key "memberships", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "transactions", "accounts", column: ["account_id", "currency"], primary_key: ["id", "currency"], name: "transactions_account_currency_fk", on_delete: :restrict
  add_foreign_key "transactions", "accounts", column: ["account_id", "household_id"], primary_key: ["id", "household_id"], name: "transactions_account_household_fk", on_delete: :restrict
  add_foreign_key "transactions", "categories", column: ["category_id", "household_id"], primary_key: ["id", "household_id"], name: "transactions_category_household_fk", on_delete: :restrict
  add_foreign_key "transactions", "households"
  add_foreign_key "transactions", "transfers", on_delete: :restrict
  add_foreign_key "transfers", "households"
end
