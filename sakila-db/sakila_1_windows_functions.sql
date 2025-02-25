-- Active: 1740077473979@@127.0.0.1@3306@sakila
-- Sommaire :
    -- 1] Analyse mensuelle des locations de films.
    -- 2] Analyse des revenus des films par catégorie.
    -- 3] Analyse des performances des employés du magasin.
    -- 4] Analyse de la fidélité des clients.

    -- 5] Analyse des performances et fidélité des clients en fonction des locations et des paiements. 
    -- 6] Analyse des films, performances des acteurs et rentabilité des magasins. 

---------------------------------------------------------------------------------------------------------------------------------

-- 📌 1] Analyse mensuelle des locations de films.
    -- Input : tables `rental` et `customer`
    -- Output :  
        -- Le mois et l’année de location (`year_month_rental`)
        -- Le nom complet du client (`customer_name`)
        -- Le nombre total de locations effectuées par ce client dans le mois (`total_rentals`)
        -- Le nombre total de locations pour tout le mois (`total_rentals_in_month`)
        -- Le classement des clients dans chaque mois en fonction de leurs locations (`rank_customers`)
        -- Les résultats sont triés du mois le plus récent au plus ancien, puis du client ayant loué le plus au moins actif.

WITH RentalsByCustomMonth AS (
    SELECT 
        DATE_FORMAT(r.rental_date, '%Y-%m') AS year_month_rental,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        COUNT(r.rental_id) AS total_rentals
    FROM rental r
    JOIN customer c ON r.customer_id = c.customer_id
    GROUP BY DATE_FORMAT(r.rental_date, '%Y-%m'), customer_name
)
SELECT
    year_month_rental,
    customer_name,
    total_rentals,
    RANK() OVER (PARTITION BY year_month_rental ORDER BY total_rentals DESC) AS rank_customers,
    SUM(total_rentals) OVER (PARTITION BY year_month_rental) AS total_rentals_in_month
FROM RentalsByCustomMonth
ORDER BY year_month_rental DESC, rank_customers;


-- 📌 2] Analyse des revenus des films par catégorie
    -- Input : Tables `film`, `film_category`, `category`, `inventory` et `rental`
    -- Output :  
        -- Le nom de la catégorie (`category_name`)
        -- Le nombre total de locations pour cette catégorie (`total_rentals`)
        -- Le revenu total généré (`total_revenue`), basé sur `rental_rate * nombre de locations`
        -- Le classement des catégories en fonction du revenu (`rank_by_revenue`)
        -- Le revenu moyen par location pour chaque catégorie (`average_revenue_per_rental`)
    
WITH TotalRentalFilm AS (SELECT
    i.film_id,
    COUNT(rental_id) AS total_rentals
FROM inventory i 
JOIN rental r ON r.inventory_id = i.inventory_id
GROUP BY i.film_id
),
CategoryRevenue AS(
    SELECT DISTINCT
        c.name AS category_name,
        SUM(trf.total_rentals) AS total_rentals_category,
        SUM(f.rental_rate * trf.total_rentals) AS total_revenue,
        SUM(f.rental_rate * trf.total_rentals) / SUM(trf.total_rentals) AS average_revenue_per_rental
    FROM film f 
    JOIN film_category fc ON f.film_id = fc.film_id
    JOIN category c ON fc.category_id = c.category_id
    JOIN TotalRentalFilm trf ON f.film_id = trf.film_id
    GROUP BY c.name
)
SELECT 
    category_name,
    total_rentals_category,
    total_revenue,
    average_revenue_per_rental,
    RANK() OVER (ORDER BY total_revenue DESC) AS rank_by_revenue
FROM CategoryRevenue;


-- 📌 3] Analyse des performances des employés du magasin
    -- Input : Tables `staff` et `payment`
    -- Output :  
        -- Le mois et l’année (`year_month_payment`)
        -- Le nom complet de l’employé (`staff_name`)
        -- Le nombre total de paiements enregistrés (`total_transactions`)
        -- Le montant total des paiements (`total_revenue`)
        -- Le montant total des paiements du mois précédent (`previous_month_revenue`)
        -- La variation en pourcentage des revenus d'un mois à l'autre (`revenue_change_pct`)
        -- Le classement des employés dans le mois en fonction de leur chiffre d’affaires (`rank_in_month`)
        -- Le chiffre d'affaires cumulé de chaque employé depuis le début (`cumulative_revenue`)

WITH PerformanceEmployeMonth AS (
    SELECT
        s.staff_id AS staff_id,
        DATE_FORMAT(p.payment_date, '%Y-%m') AS year_month_payment,
        CONCAT(s.first_name, ' ', s.last_name) AS staff_name,
        COUNT(p.payment_id) AS total_transactions,
        SUM(p.amount) AS total_revenue
    FROM payment p
    JOIN staff s ON p.staff_id = s.staff_id
    GROUP BY year_month_payment, staff_name, staff_id
)
SELECT 
    year_month_payment,
    staff_name,
    total_transactions,
    total_revenue,
    LAG(total_revenue) OVER (PARTITION BY staff_id ORDER BY year_month_payment) AS previous_month_revenue,
    ROUND(
        (total_revenue - COALESCE(LAG(total_revenue) OVER (PARTITION BY staff_id ORDER BY year_month_payment), 0)) /
        NULLIF(COALESCE(LAG(total_revenue) OVER (PARTITION BY staff_id ORDER BY year_month_payment), 0), 0) * 100, 2
    ) AS revenue_change_pct,
    RANK() OVER (PARTITION BY year_month_payment ORDER BY total_revenue DESC) AS rank_in_month,
    SUM(total_revenue) OVER (
        PARTITION BY staff_id 
        ORDER BY year_month_payment ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_revenue
FROM PerformanceEmployeMonth
ORDER BY year_month_payment DESC, rank_in_month;


-- 📌 4] Analyse de la fidélité des clients
    -- Input : Tables `customer` et `rental`  
    -- Output :  
        -- Le nom complet du client (`customer_name`)  
        -- Le nombre total de locations effectuées (`total_rentals`)  
        -- La date de la première location (`first_rental_date`)  
        -- La date de la dernière location (`last_rental_date`)  
        -- Le nombre moyen de locations par mois (`avg_rentals_per_month`)  
        -- Le classement des clients selon leur nombre total de locations (`rank_by_rentals`)  
        -- La catégorie de fidélité du client (`loyalty_category`) :  
            --   **"VIP"** : Plus de 40 locations  
            --   **"Régulier"** : Entre 20 et 40 locations  
            --   **"Occasionnel"** : Moins de 20 locations  

WITH table_customer AS (
    SELECT 
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        COUNT(r.rental_id) AS total_rentals,
        MIN(r.rental_date) AS first_rental_date,
        MAX(r.rental_date) AS last_rental_date
    FROM customer c 
    JOIN rental r ON c.customer_id = r.customer_id
    GROUP BY c.customer_id
)
SELECT DISTINCT
    tc.customer_name,
    tc.total_rentals,
    tc.first_rental_date,
    tc.last_rental_date,
    (tc.total_rentals / (TIMESTAMPDIFF(MONTH, tc.first_rental_date, tc.last_rental_date) + 1)) AS avg_rentals_per_month,
    RANK() OVER (ORDER BY tc.total_rentals DESC) AS rank_by_rentals,
    CASE 
        WHEN tc.total_rentals > 40 THEN 'VIP'
        WHEN tc.total_rentals BETWEEN 20 AND 40 THEN 'Régulier'
        ELSE 'Occasionnel'
    END AS loyalty_category
FROM table_customer tc 
JOIN rental r ON tc.customer_id = r.customer_id
LIMIT 0, 10000


-- 📌 5] Analyse des performances et fidélité des clients en fonction des locations et des paiements. 
    -- Input :  Tables `customer`, `rental`, `payment`.
    -- Output :  
        -- `customer_name` : Nom complet du client.  
        -- `total_rentals`, `total_payments` : Nombre total de locations effectuées et payé par le client.  
        -- `avg_payment_per_rental` : Moyenne du montant payé par location.  
        -- `first_rental_date`, `last_rental_date` : Date de la première et dernière location.  
        -- `avg_rentals_per_month` : Nombre moyen de locations par mois.  
        -- `last_3_months_payments`, `last_last_3_months_payments` : Montant payé au cours des (3) et (entre 3 et 6) derniers mois.  
        -- `rank_by_payments` : Classement des clients selon leurs paiements totaux.  
        -- `customer_category` : Catégorie de fidélité du client :  
        --     **"Premium"** si `total_payments > 4000`  
        --     **"Régulier"** si `total_payments` entre `3000 et 4000`  
        --     **"Occasionnel"** si `total_payments < 3000`  
        -- `payment_growth_pct` : Croissance des paiements en pourcentage sur les 3 derniers mois.  

WITH LastPaymentDate AS (
    SELECT MAX(payment_date) AS last_payment_date FROM payment
),
Table_Customers AS( 
    SELECT
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        COUNT(r.rental_id) AS total_rentals,
        SUM(p.amount) AS total_payments,
        MIN(r.rental_date) AS first_rental_date,
        MAX(r.rental_date) AS last_rental_date,
        SUM(CASE 
                WHEN p.payment_date >= DATE_SUB(lpd.last_payment_date, INTERVAL 3 MONTH) 
                THEN p.amount 
                ELSE 0 
            END) AS last_3_months_payments,
        SUM(CASE 
                WHEN p.payment_date >= DATE_SUB(lpd.last_payment_date, INTERVAL 6 MONTH) AND p.payment_date < DATE_SUB(lpd.last_payment_date, INTERVAL 3 MONTH)
                THEN p.amount 
                ELSE 0 
            END) AS last_last_3_months_payments
    FROM customer c
    JOIN rental r ON c.customer_id = r.customer_id
    JOIN payment p ON c.customer_id = p.customer_id
    JOIN LastPaymentDate lpd ON 1=1
    GROUP BY c.customer_id
)
SELECT
    customer_name, total_rentals, total_payments, 
    total_payments/NULLIF(total_rentals, 0) AS avg_payment_per_rental,
    first_rental_date, last_rental_date,
    total_rentals/(TIMESTAMPDIFF(Month, first_rental_date, last_rental_date)+1) AS avg_rentals_per_month,
    last_3_months_payments, last_last_3_months_payments,
    DENSE_RANK() OVER (ORDER BY total_payments DESC) AS rank_by_payments,
    CASE
        WHEN total_payments > 4000 THEN 'Premium'
        WHEN total_payments > 3000 THEN 'Régulier'
        ELSE 'Occasionnel'
    END AS customer_category,
    (last_3_months_payments-last_last_3_months_payments)/NULLIF(last_last_3_months_payments, 0) *100 AS payment_growth_pct
FROM Table_Customers
ORDER BY last_3_months_payments DESC;

-- On check le nombre de payment effectué ces derniers mois. 

WITH LastPaymentDate AS (
    SELECT MAX(payment_date) AS last_payment_date FROM payment
),
PaymentsPeriods AS (
    SELECT
        p.payment_id,
        LEAST(6, FLOOR(TIMESTAMPDIFF(MONTH, p.payment_date, lpd.last_payment_date))) + 1 AS periods
    FROM payment p
    JOIN LastPaymentDate lpd ON 1=1
)
SELECT 
    COUNT(payment_id),
    periods
FROM PaymentsPeriods
GROUP BY periods


-- 📌  6] Analyse des films, performances des acteurs et rentabilité des magasins. 
    -- Input : `actor`, `film_actor`, `film`, `inventory`, `rental`, et `payment`. 
    -- Output :  
        -- `film_title` : Nom du film.  
        -- `total_rentals` : Nombre total de locations du film.  
        -- `total_revenue` : Revenu total généré par les paiements associés aux locations du film.  
        -- `total_replacement_cost` : Coût total de remplacement du film.  
        -- `profitability_ratio` : Rentabilité du film.  
        -- `top_actor_name` : Acteur ayant joué dans le plus de films populaires.  

WITH ActorPerf AS (
    SELECT 
        a.actor_id,
        CONCAT(a.first_name, ' ', a.last_name) AS actor_name,
        COUNT(fa.film_id) AS nbr_films
    FROM actor a
    JOIN film_actor fa ON a.actor_id = fa.actor_id
    GROUP BY a.actor_id
),
TableFilm AS (
    SELECT 
        f.film_id,
        f.title AS film_title,
        COUNT(r.rental_id) AS total_rentals,
        SUM(p.amount) AS total_revenue,
        SUM(f.replacement_cost) AS total_replacement_cost,
        (SELECT a.actor_id 
         FROM film_actor fa
         JOIN ActorPerf a ON a.actor_id = fa.actor_id
         WHERE fa.film_id = f.film_id
         ORDER BY a.nbr_films DESC 
         LIMIT 1) AS best_actor_id

    FROM film f
    JOIN inventory i USING (film_id)
    JOIN rental r ON r.inventory_id = i.inventory_id
    JOIN payment p ON p.customer_id = r.customer_id 
        AND p.payment_date BETWEEN r.rental_date AND DATE_ADD(r.rental_date, INTERVAL 1 DAY)
    GROUP BY f.film_id
)
SELECT 
    tf.film_title,
    tf.total_rentals, 
    tf.total_revenue,
    tf.total_replacement_cost,
    (tf.total_revenue / NULLIF(tf.total_replacement_cost, 0)) * 100 AS profitability_ratio,
    ap.actor_name AS top_actor_name,
    DENSE_RANK() OVER (ORDER BY tf.total_revenue DESC) AS film_rank
FROM TableFilm tf
LEFT JOIN ActorPerf ap ON ap.actor_id = tf.best_actor_id;






