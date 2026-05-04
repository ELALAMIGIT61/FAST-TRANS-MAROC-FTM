-- Create driver-documents storage bucket
-- Documents: driver_license, vehicle_registration, insurance, technical_inspection
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'driver-documents',
  'driver-documents',
  false,
  5242880,
  ARRAY['image/jpeg', 'image/png', 'application/pdf']
);
