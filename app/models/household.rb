class Household < ApplicationRecord
  has_many :memberships
  has_many :users, through: :memberships
  has_many :accounts
  has_many :categories

  validates :name, presence: true
  validates :base_currency, presence: true, format: { with: /\A[A-Z]{3}\z/, message: "must be a valid ISO 4217 currency code" }

  # Crea las categorías por defecto que falten (config/default_categories.yml).
  # Idempotente: compara por nombre sin mayúsculas entre los padres, también archivados.
  # Devuelve cuántas ha creado.
  def seed_default_categories!
    existing = categories.roots.pluck(Arel.sql("lower(name)")).to_set

    transaction do
      self.class.default_categories.count do |attributes|
        next false if existing.include?(attributes[:name].downcase)

        categories.create!(attributes)
      end
    end
  end

  def self.default_categories
    @default_categories ||= YAML.load_file(Rails.root.join("config/default_categories.yml"))
      .flat_map { |kind, entries| entries.map { |entry| entry.symbolize_keys.merge(kind: kind) } }
      .freeze
  end
end
