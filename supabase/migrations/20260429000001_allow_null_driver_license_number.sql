-- Allow driver_license_number to be null at driver profile creation
-- It will be filled at step 2 (LegalDocumentsScreen)
ALTER TABLE drivers
ALTER COLUMN driver_license_number DROP NOT NULL;
