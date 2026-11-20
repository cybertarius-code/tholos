class CreateCategories < ActiveRecord::Migration[8.1]
  KINDS = %w[ expense income ].freeze
  REPORT_GROUPS = %w[ essentials lifestyle growth work finance other ].freeze

  def change
    create_table :categories do |t|
      t.references :household, null: false, foreign_key: true, index: false
      t.bigint :parent_id
      t.string :name, null: false
      t.string :kind, null: false
      t.string :report_group
      t.string :color, null: false
      t.string :icon, null: false
      t.integer :position, null: false, default: 0
      t.datetime :archived_at
      t.timestamps
    end

    # Unicidad sin distinguir mayúsculas en el mismo nivel; incluye archivadas y padres (NULL)
    add_index :categories, "household_id, parent_id, lower(name)",
      unique: true, nulls_not_distinct: true, name: "index_categories_on_household_parent_lower_name"
    add_index :categories, :parent_id
    add_index :categories, [ :household_id, :kind, :position ]

    # La hija hereda el tipo del padre y solo se mueve entre padres del mismo tipo
    add_index :categories, [ :id, :kind ], unique: true
    add_foreign_key :categories, :categories, column: [ :parent_id, :kind ], primary_key: [ :id, :kind ],
      on_delete: :restrict, name: "categories_parent_kind_fk"

    add_check_constraint :categories, "kind IN (#{quoted(KINDS)})", name: "categories_kind_check"
    add_check_constraint :categories, "report_group IS NULL OR report_group IN (#{quoted(REPORT_GROUPS)})",
      name: "categories_report_group_check"
    add_check_constraint :categories, "parent_id IS NULL OR report_group IS NULL", name: "categories_report_group_only_on_parents"
  end

  private
    def quoted(values)
      values.map { |value| "'#{value}'" }.join(", ")
    end
end
