USE ecommerce_db;

-- =====================================================================
-- TRANSAÇÃO DE CHECKOUT COMPLETA
-- Garante atomicidade: ou o pedido é criado + estoque debitado + carrinho
-- limpo, ou NADA acontece.
-- =====================================================================

DELIMITER //

CREATE PROCEDURE sp_checkout(
    IN  p_user_id       INT,
    IN  p_payment_method VARCHAR(50)
)
BEGIN
    DECLARE v_variant_id  INT;
    DECLARE v_qty         INT;
    DECLARE v_unit_price  DECIMAL(10,2);
    DECLARE v_total       DECIMAL(10,2) DEFAULT 0;
    DECLARE v_ship_cost   DECIMAL(10,2) DEFAULT 20.00;
    DECLARE v_tax         DECIMAL(10,2);
    DECLARE v_order_id    INT;
    DECLARE v_row         INT DEFAULT 0;   -- handler para fim do cursor
    DECLARE v_done        INT DEFAULT 0;
    DECLARE cur           CURSOR FOR
        SELECT ci.product_variant_id, ci.quantity, pv.price
        FROM cart_items ci
        JOIN product_variants pv ON pv.id = ci.product_variant_id
        WHERE ci.user_id = p_user_id
        FOR UPDATE;  -- <-- LOCK pessimista no estoque, evita oversell
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;

    START TRANSACTION;

    OPEN cur;
        read_loop: LOOP
            FETCH cur INTO v_variant_id, v_qty, v_unit_price;
            IF v_done THEN LEAVE read_loop; END IF;

            -- Valida estoque DENTRO da transação (com lock ativo)
            IF (SELECT stock_quantity FROM product_variants WHERE id = v_variant_id) < v_qty THEN
                SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Estoque insuficiente para a variante';
            END IF;

            SET v_total = v_total + (v_qty * v_unit_price);
        END LOOP;
    CLOSE cur;

    SET v_tax = ROUND(v_total * 0.1673, 2);  -- ~ICMS ilustrativo

    -- 1. Cria o pedido com SNAPSHOT do endereço
    INSERT INTO orders (user_id, order_status, total_amount, shipping_cost, tax_amount,
                        shipping_street, shipping_city, shipping_state,
                        shipping_zip_code, shipping_country)
    SELECT p_user_id, 'pending', v_total + v_ship_cost + v_tax, v_ship_cost, v_tax,
           a.street_address, a.city, a.state, a.zip_code, a.country
    FROM addresses a
    WHERE a.user_id = p_user_id AND a.is_default_shipping = TRUE;

    SET v_order_id = LAST_INSERT_ID();

    -- 2. Cria itens com SNAPSHOT do preço + debita estoque
    INSERT INTO order_items (order_id, product_variant_id, quantity, unit_price)
    SELECT v_order_id, ci.product_variant_id, ci.quantity, pv.price
    FROM cart_items ci
    JOIN product_variants pv ON pv.id = ci.product_variant_id
    WHERE ci.user_id = p_user_id;

    UPDATE product_variants v
    JOIN cart_items ci ON ci.product_variant_id = v.id
    SET v.stock_quantity = v.stock_quantity - ci.quantity
    WHERE ci.user_id = p_user_id;

    -- 3. Registra pagamento pendente
    INSERT INTO payments (order_id, payment_method, amount, status)
    VALUES (v_order_id, p_payment_method, v_total + v_ship_cost + v_tax, 'pending');

    -- 4. Limpa o carrinho
    DELETE FROM cart_items WHERE user_id = p_user_id;

    COMMIT;

    SELECT v_order_id AS order_id;
END //

DELIMITER ;

-- Uso:
-- CALL sp_checkout(2, 'credit_card');