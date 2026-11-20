# Categorías de dos niveles: padre = categoría concreta, hija = subcategoría.
# Reglas: ADR-0015. La BD garantiza la herencia del tipo (FK compuesta), la
# unicidad sin mayúsculas y que solo los padres llevan grupo de informe.
class Category < ApplicationRecord
  include ConstraintViolationErrors

  KINDS = %w[ expense income ].freeze
  REPORT_GROUPS = %w[ essentials lifestyle growth work finance other ].freeze
  # Paleta cerrada (tokens --color-cat-* con contraste AA en claro y oscuro)
  COLORS = %w[ navy teal green gold copper red plum slate ].freeze
  ICONS = {
    "cart" => "🛒", "home" => "🏠", "family" => "👪", "car" => "🚗", "health" => "🩺",
    "pet" => "🐾", "restaurant" => "🍽️", "leisure" => "🎭", "travel" => "✈️",
    "subscription" => "🔁", "care" => "💇", "gift" => "🎁", "education" => "📚",
    "work" => "💼", "bank" => "🏦", "percent" => "💸", "document" => "📄", "box" => "📦",
    "salary" => "💶", "invoice" => "🧾", "chart" => "📈", "plus" => "➕",
    "coffee" => "☕", "phone" => "📱", "sport" => "🏋️", "clothes" => "👕", "tag" => "🏷️"
  }.freeze

  belongs_to :household
  belongs_to :parent, class_name: "Category", optional: true, inverse_of: :children
  has_many :children, class_name: "Category", foreign_key: :parent_id, inverse_of: :parent,
    dependent: :restrict_with_error

  enum :kind, KINDS.index_with(&:itself), validate: true
  enum :report_group, REPORT_GROUPS.index_with(&:itself), prefix: true, validate: { allow_nil: true }

  constraint_error "categories_parent_kind_fk", :parent_id, :kind_mismatch
  constraint_error "index_categories_on_household_parent_lower_name", :name, :taken
  constraint_error "categories_report_group_only_on_parents", :report_group, :present

  normalizes :name, with: ->(name) { name.squish }

  validates :name, presence: true, length: { maximum: 60 }
  validates :name, uniqueness: { scope: %i[ household_id parent_id ], case_sensitive: false }, if: :name?
  validates :color, inclusion: { in: COLORS }
  validates :icon, inclusion: { in: ICONS.keys }
  validates :report_group, presence: true, if: -> { expense? && root? }
  validate :parent_is_a_valid_root, if: :parent_id?
  validate :parent_keeps_two_levels, if: -> { persisted? && parent_id? && parent_id_changed? }
  validate :kind_is_fixed, on: :update, if: :kind_changed?

  before_validation :inherit_from_parent
  before_create :append_to_siblings
  before_destroy :ensure_no_movements

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }
  scope :roots, -> { where(parent_id: nil) }
  scope :ordered, -> { order(:position, :id) }

  def root?
    parent_id.nil?
  end

  def archived?
    archived_at.present?
  end

  def emoji
    ICONS.fetch(icon, ICONS["tag"])
  end

  # TODO(US-0104): true si algún movimiento usa la categoría
  def movements?
    false
  end

  # Archivar un padre archiva también sus hijas
  def archive!
    transaction do
      now = Time.current
      update!(archived_at: now)
      children.active.update_all(archived_at: now, updated_at: now)
    end
  end

  # Desarchivar una hija desarchiva también su padre, para que vuelva a verse
  def unarchive!
    transaction do
      update!(archived_at: nil)
      Category.where(id: parent_id).archived.update_all(archived_at: nil, updated_at: Time.current)
    end
  end

  # La archivada del mismo nivel con el mismo nombre (sin mayúsculas), para ofrecer desarchivarla
  def archived_namesake
    return if name.blank?

    Category.archived.where(household_id: household_id, parent_id: parent_id)
      .where("lower(name) = lower(?)", name).where.not(id: id).first
  end

  # Sube o baja entre sus hermanas activas (mismo hogar, tipo y padre)
  def move!(direction)
    transaction do
      ids = siblings.active.ordered.lock.ids
      index = ids.index(id)
      target = direction.to_s == "up" ? index - 1 : index + 1
      next false if index.nil? || target.negative? || target >= ids.size

      ids[index], ids[target] = ids[target], ids[index]
      ids.each_with_index { |sibling_id, position| Category.where(id: sibling_id).update_all(position: position) }
      true
    end
  end

  private
    def siblings
      Category.where(household_id: household_id, kind: kind, parent_id: parent_id)
    end

    # Los errores van en :parent_id: en :parent, el mensaje cargaría la asociación (strict_loading).
    # Sin pasar por la asociación: con strict_loading no se puede cargar perezosamente
    def parent_category
      return if parent_id.nil?
      return parent if association(:parent).loaded? && parent&.id == parent_id

      @parent_category = nil unless @parent_category&.id == parent_id
      @parent_category ||= Category.find_by(id: parent_id)
    end

    def inherit_from_parent
      self.kind = parent_category.kind if new_record? && parent_category
      self.report_group = nil if parent_id? || income?
    end

    def append_to_siblings
      self.position = (siblings.maximum(:position) || -1) + 1
    end

    def parent_is_a_valid_root
      candidate = parent_category
      if candidate.nil? || candidate.household_id != household_id || candidate.id == id
        errors.add(:parent_id, :invalid)
      elsif candidate.parent_id?
        errors.add(:parent_id, :too_deep)
      elsif candidate.kind != kind
        errors.add(:parent_id, :kind_mismatch)
      elsif candidate.archived? && (new_record? || parent_id_changed?)
        errors.add(:parent_id, :archived)
      end
    end

    # Un padre con hijas no puede pasar a ser hija (serían tres niveles)
    def parent_keeps_two_levels
      errors.add(:parent_id, :has_children) if children.exists?
    end

    def kind_is_fixed
      errors.add(:kind, :locked) if movements? || children.exists?
    end

    def ensure_no_movements
      return unless movements?

      errors.add(:base, :has_movements)
      throw :abort
    end
end
