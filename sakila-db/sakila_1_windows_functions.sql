-- 📌 1] Analyse mensuelle des locations de films.
    -- Input : tables rental et customer
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
        SUM(f.rental_rate * trf.total_rentals) AS total_revenue
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
    RANK() OVER (ORDER BY total_revenue) AS rank_by_revenue
FROM CategoryRevenue


