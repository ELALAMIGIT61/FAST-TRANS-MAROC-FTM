-- Allow legal document fields to be null at step 1 (VehicleInfoScreen)
-- Architecture: INSERT at step 1, UPDATE at step 2 (LegalDocumentsScreen)
-- Frontend validation ensures all fields are filled before step 2 submission
ALTER TABLE drivers
  ALTER COLUMN driver_license_expiry DROP NOT NULL,
  ALTER COLUMN vehicle_registration_number DROP NOT NULL,
  ALTER COLUMN insurance_number DROP NOT NULL,
  ALTER COLUMN insurance_expiry DROP NOT NULL,
  ALTER COLUMN technical_inspection_expiry DROP NOT NULL;
