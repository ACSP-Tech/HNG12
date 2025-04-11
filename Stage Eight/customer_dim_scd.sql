-- Creating a customer_dim SCD Table
CREATE TABLE customer_dim_scd (
   surrogate_key SERIAL PRIMARY KEY,  -- Surrogate key for uniqueness
   customer_id VARCHAR(50),           -- Natural key from source system
   customer_name TEXT NOT NULL,
   address TEXT,
   telephone VARCHAR(20),
   effective_date DATE NOT NULL,      -- Date when this record became effective
   expiration_date DATE,              -- Date when this record was replaced
   current_flag BOOLEAN NOT NULL DEFAULT TRUE
);

-- Creating a Trigger Function for SCD Type 2 Updates
CREATE OR REPLACE FUNCTION scd_customer_dim_update() 
RETURNS TRIGGER AS $$  
BEGIN
    -- Insert OLD record into customer_dim_scd (archive old data)
    INSERT INTO customer_dim_scd (customer_id, customer_name, address, telephone, effective_date, expiration_date, current_flag)
    VALUES (OLD.customer_id, OLD.customer_name, OLD.address, OLD.telephone, CURRENT_DATE, CURRENT_DATE, FALSE);

    -- Allow the update to proceed normally in customer_dim
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Attaching the trigger function to fire BEFORE updating customer_dim
CREATE TRIGGER trg_scd_customer_dim_update
BEFORE UPDATE ON customer_dim
FOR EACH ROW 
EXECUTE FUNCTION scd_customer_dim_update();