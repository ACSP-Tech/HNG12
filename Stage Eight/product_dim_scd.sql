CREATE TABLE product_dim_scd (
    surrogate_key SERIAL PRIMARY KEY,     -- Unique identifier for each history record
    product_id VARCHAR(50),               -- Natural key (same for a given product)
    product_name TEXT NOT NULL,
    quantity_available INT,
    unit_price DECIMAL(10,2) NOT NULL,
    cost_price DECIMAL(10,2) NOT NULL,
    effective_date DATE NOT NULL,         -- When this version became effective
    expiration_date DATE,                 -- When this version was superseded (NULL if current)
    current_flag BOOLEAN NOT NULL DEFAULT TRUE  -- Indicates if this is the current version in history
);
CREATE OR REPLACE FUNCTION scd_product_dim_capture_history() 
RETURNS TRIGGER AS $$
BEGIN
    -- If an active history record exists for this product, mark it as expired.
    UPDATE product_dim_scd
    SET expiration_date = CURRENT_DATE,
        current_flag = FALSE
    WHERE product_id = OLD.product_id
      AND current_flag = TRUE;

    -- Insert the old record into the history table.
    INSERT INTO product_dim_scd (
         product_id, product_name, quantity_available, unit_price, cost_price, effective_date, current_flag
    )
    VALUES (
         OLD.product_id, OLD.product_name, OLD.quantity_available, OLD.unit_price, OLD.cost_price, CURRENT_DATE, TRUE
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_capture_product_history
BEFORE UPDATE ON product_dim
FOR EACH ROW 
EXECUTE FUNCTION scd_product_dim_capture_history();