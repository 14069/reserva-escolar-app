-- Estrutura minima para suportar cadastro de escola e primeiro tecnico.
-- Ajuste tipos, constraints e campos extras conforme o banco real da API.

CREATE TABLE IF NOT EXISTS schools (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(150) NOT NULL,
  school_code VARCHAR(20) NOT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_schools_school_code (school_code)
);

CREATE TABLE IF NOT EXISTS users (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  school_id INT UNSIGNED NOT NULL,
  name VARCHAR(150) NOT NULL,
  email VARCHAR(190) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  role ENUM('technician', 'teacher') NOT NULL DEFAULT 'teacher',
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  api_token VARCHAR(80) DEFAULT NULL,
  api_token_expires_at DATETIME DEFAULT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_users_email_school (school_id, email),
  KEY idx_users_school_id (school_id),
  CONSTRAINT fk_users_school
    FOREIGN KEY (school_id) REFERENCES schools(id)
    ON DELETE CASCADE
);

-- Dados opcionais para validar o fluxo manualmente:
-- INSERT INTO schools (name, school_code) VALUES ('Escola Exemplo', 'ESC001');
