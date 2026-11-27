# Los modelos internos de Active Storage (Blob, Attachment, VariantRecord) cargan
# sus asociaciones a su manera al purgar o generar variantes: strict_loading_by_default
# (desarrollo y test) los rompería. Los modelos de la app siguen con strict_loading:
# Transaction#receipt hay que cargarlo con with_attached_receipt (US-0107).
ActiveSupport.on_load(:active_storage_record) do
  self.strict_loading_by_default = false
end
