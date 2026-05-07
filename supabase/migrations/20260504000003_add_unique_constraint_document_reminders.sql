-- Add UNIQUE constraint on (driver_id, document_type) for document_reminders
-- Required for upsert ON CONFLICT in saveDriverDocuments()
ALTER TABLE document_reminders
ADD CONSTRAINT document_reminders_driver_id_document_type_key
UNIQUE (driver_id, document_type);
