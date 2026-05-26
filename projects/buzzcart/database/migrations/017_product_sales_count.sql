BEGIN;

ALTER TABLE products
ADD COLUMN IF NOT EXISTS sales_count INT NOT NULL DEFAULT 0;

UPDATE products p
SET sales_count = COALESCE((
    SELECT SUM(oi.quantity)::INT
    FROM order_items oi
    JOIN orders o ON o.id = oi.order_id
    WHERE oi.product_id = p.id
      AND o.status IN ('delivered', 'completed')
), 0);

CREATE OR REPLACE FUNCTION sync_product_sales_count_snapshot(p_product_id UUID)
RETURNS void AS $$
BEGIN
    UPDATE products p
    SET sales_count = COALESCE((
        SELECT SUM(oi.quantity)::INT
        FROM order_items oi
        JOIN orders o ON o.id = oi.order_id
        WHERE oi.product_id = p.id
          AND o.status IN ('delivered', 'completed')
    ), 0)
    WHERE p.id = p_product_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sync_product_sales_count_from_order_item()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM sync_product_sales_count_snapshot(COALESCE(NEW.product_id, OLD.product_id));
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sync_product_sales_count_from_order()
RETURNS TRIGGER AS $$
DECLARE
    affected_product_id UUID;
BEGIN
    FOR affected_product_id IN
        SELECT DISTINCT oi.product_id
        FROM order_items oi
        WHERE oi.order_id = COALESCE(NEW.id, OLD.id)
          AND oi.product_id IS NOT NULL
    LOOP
        PERFORM sync_product_sales_count_snapshot(affected_product_id);
    END LOOP;

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS order_items_sync_sales_count_trigger ON order_items;
CREATE TRIGGER order_items_sync_sales_count_trigger
AFTER INSERT OR UPDATE OR DELETE ON order_items
FOR EACH ROW
EXECUTE FUNCTION sync_product_sales_count_from_order_item();

DROP TRIGGER IF EXISTS orders_sync_sales_count_trigger ON orders;
CREATE TRIGGER orders_sync_sales_count_trigger
AFTER UPDATE OF status OR DELETE ON orders
FOR EACH ROW
EXECUTE FUNCTION sync_product_sales_count_from_order();

COMMIT;
