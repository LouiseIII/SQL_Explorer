-- Sommaire :
    -- 1] Analyse mensuelle des locations de films.
    -- 2] Analyse des revenus des films par catégorie.
    -- 3] Analyse des performances des employés du magasin.
    -- 4] Analyse de la fidélité des clients.


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
