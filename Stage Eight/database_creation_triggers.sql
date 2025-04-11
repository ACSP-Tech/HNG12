-- Create customer dimension table
CREATE TABLE customer_dim (
    customer_id VARCHAR(50) PRIMARY KEY,
    customer_name TEXT NOT NULL,
    address TEXT,
    telephone VARCHAR(20)
);

-- Create supplier dimension table
CREATE TABLE supplier_dim (
    supplier_id VARCHAR(50) PRIMARY KEY,
    supplier_name TEXT NOT NULL,
    address TEXT,
    telephone VARCHAR(20)
);

-- Create store dimension table
CREATE TABLE store_dim (
    store_id VARCHAR(50) PRIMARY KEY,
    store_name TEXT NOT NULL,
    store_location TEXT,
    store_contact VARCHAR(20)
);

-- Create product dimension table
CREATE TABLE product_dim (
    product_id VARCHAR(50) PRIMARY KEY,
    product_name TEXT NOT NULL,
    quantity_available INT DEFAULT 0, 
    unit_price DECIMAL(10,2) NOT NULL,
    cost_price DECIMAL(10,2) NOT NULL
);

-- Create purchase invoice fact table with a surrogate primary key.
CREATE TABLE purchase_invoice_fact (
    fact_id SERIAL PRIMARY KEY,       -- Surrogate key for unique identification
    purchase_id VARCHAR(50),          -- Now not unique; can be repeated
    purchase_date DATE NOT NULL,
    supplier_id VARCHAR(50) REFERENCES supplier_dim(supplier_id) ON DELETE CASCADE,
    supplier_name TEXT NOT NULL,
    product_id VARCHAR(50) REFERENCES product_dim(product_id) ON DELETE CASCADE,
    product_name TEXT NOT NULL,
    quantity INT NOT NULL CHECK (quantity >= 0),
    cost_price DECIMAL(10,2) NOT NULL CHECK (cost_price >= 0),
    line_total DECIMAL(10,2) GENERATED ALWAYS AS (COALESCE(quantity * cost_price, 0)) STORED,
    store_id VARCHAR(50) REFERENCES store_dim(store_id) ON DELETE CASCADE
);

-- Create sales invoice fact table with a surrogate primary key.
CREATE TABLE sales_invoice_fact (
    fact_id SERIAL PRIMARY KEY,       -- Surrogate key for unique identification
    invoice_id VARCHAR(50),           -- Now not unique; can be repeated
    invoice_date DATE NOT NULL,
    customer_id VARCHAR(50) REFERENCES customer_dim(customer_id) ON DELETE CASCADE,
    customer_name TEXT NOT NULL,
    product_id VARCHAR(50) REFERENCES product_dim(product_id) ON DELETE CASCADE,
    product_name TEXT,
    quantity INT NOT NULL CHECK (quantity >= 0),
    unit_price DECIMAL(10,2) NOT NULL CHECK (unit_price >= 0),
    line_total DECIMAL(10,2) GENERATED ALWAYS AS (COALESCE(quantity * unit_price, 0)) STORED,
    store_id VARCHAR(50) REFERENCES store_dim(store_id) ON DELETE CASCADE
);

----------------------------------------------------------
-- Trigger Functions & Triggers
----------------------------------------------------------

-- Trigger function: update product quantity on purchase
CREATE OR REPLACE FUNCTION update_quantity_on_purchase() 
RETURNS TRIGGER AS $$
BEGIN
    UPDATE product_dim 
    SET quantity_available = quantity_available + NEW.quantity
    WHERE product_id = NEW.product_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_quantity_purchase
AFTER INSERT ON purchase_invoice_fact
FOR EACH ROW 
EXECUTE FUNCTION update_quantity_on_purchase();

-- Trigger function: update product quantity on sale
CREATE OR REPLACE FUNCTION update_quantity_on_sales() 
RETURNS TRIGGER AS $$
BEGIN
    UPDATE product_dim 
    SET quantity_available = quantity_available - NEW.quantity
    WHERE product_id = NEW.product_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_quantity_sales
AFTER INSERT ON sales_invoice_fact
FOR EACH ROW 
EXECUTE FUNCTION update_quantity_on_sales();

-- Trigger function: populate product_name in sales_invoice_fact from product_dim
CREATE OR REPLACE FUNCTION populate_sales_invoice_product_name() 
RETURNS TRIGGER AS $$
BEGIN
    SELECT p.product_name 
      INTO NEW.product_name
      FROM product_dim p
     WHERE p.product_id = NEW.product_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_populate_sales_invoice_product_name
BEFORE INSERT ON sales_invoice_fact
FOR EACH ROW 
EXECUTE FUNCTION populate_sales_invoice_product_name();

-- Trigger function: populate product_name and supplier_name in purchase_invoice_fact
CREATE OR REPLACE FUNCTION populate_purchase_invoice_names() 
RETURNS TRIGGER AS $$
BEGIN
    -- Populate product_name from product_dim
    SELECT p.product_name
      INTO NEW.product_name
      FROM product_dim p
     WHERE p.product_id = NEW.product_id;
    
    -- Populate supplier_name from supplier_dim
    SELECT s.supplier_name
      INTO NEW.supplier_name
      FROM supplier_dim s
     WHERE s.supplier_id = NEW.supplier_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_populate_purchase_invoice_names
BEFORE INSERT ON purchase_invoice_fact
FOR EACH ROW 
EXECUTE FUNCTION populate_purchase_invoice_names();

-- Trigger function: populate customer_name in sales_invoice_fact from customer_dim
CREATE OR REPLACE FUNCTION populate_sales_invoice_customer_name() 
RETURNS TRIGGER AS $$
BEGIN
    SELECT c.customer_name
      INTO NEW.customer_name
      FROM customer_dim c
     WHERE c.customer_id = NEW.customer_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_populate_sales_invoice_customer_name
BEFORE INSERT ON sales_invoice_fact
FOR EACH ROW 
EXECUTE FUNCTION populate_sales_invoice_customer_name();