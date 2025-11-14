Rails.application.config.active_record.encryption.primary_key =
  ENV.fetch("ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY") do
    Rails.application.credentials.dig(:active_record_encryption, :primary_key)
  end

Rails.application.config.active_record.encryption.deterministic_key =
  ENV.fetch("ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY") do
    Rails.application.credentials.dig(:active_record_encryption, :deterministic_key)
  end

Rails.application.config.active_record.encryption.key_derivation_salt =
  ENV.fetch("ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT") do
    Rails.application.credentials.dig(:active_record_encryption, :key_derivation_salt)
  end
