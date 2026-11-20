# Convierte violaciones de restricciones de PostgreSQL (CHECK, FK, índice único)
# en errores de validación en lugar de un 500 (ADR-0014, decisión A).
#
#   constraint_error "categories_parent_kind_fk", :parent, :kind_mismatch
#
# Al guardar, si la BD rechaza la fila por una restricción declarada, se añade
# el error traducido, `save` devuelve false y `save!` lanza RecordInvalid.
# Una restricción no declarada se vuelve a lanzar. Las operaciones masivas
# (`insert_all`, `update_all`, `update_column`) no pasan por aquí.
module ConstraintViolationErrors
  extend ActiveSupport::Concern

  VIOLATIONS = [
    ActiveRecord::CheckViolation,
    ActiveRecord::RecordNotUnique,
    ActiveRecord::InvalidForeignKey
  ].freeze

  included do
    class_attribute :constraint_errors, instance_writer: false, default: {}
  end

  class_methods do
    def constraint_error(constraint_name, attribute, type)
      self.constraint_errors = constraint_errors.merge(constraint_name.to_s => [ attribute, type ])
    end
  end

  def save!(...)
    super
  rescue ActiveRecord::RecordNotSaved
    raise ActiveRecord::RecordInvalid, self if @constraint_violated

    raise
  end

  private
    def create_or_update(...)
      @constraint_violated = false
      # Savepoint: una sentencia fallida no deja abortada la transacción exterior
      self.class.transaction(requires_new: true) { super }
    rescue *VIOLATIONS => error
      attribute, type = constraint_errors[violated_constraint_name(error)]
      raise unless attribute

      @constraint_violated = true
      errors.add(attribute, type)
      false
    end

    def violated_constraint_name(error)
      error.cause.result&.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME) if error.cause.respond_to?(:result)
    end
end
