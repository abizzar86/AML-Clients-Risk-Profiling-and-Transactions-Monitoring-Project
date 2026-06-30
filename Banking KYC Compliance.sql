select * from clients_with_fatf_ofac;
select * from transactions_with_fatf_ofac;

--data Demographic by Sector Risk
SELECT 
    sector_risk AS Risk_Category,
    COUNT(sector_risk) AS Total_Clients,
    ROUND(COUNT(sector_risk) * 100.0 / SUM(COUNT(sector_risk)) OVER(), 2) AS Percentage
FROM clients_with_fatf_ofac
GROUP BY sector_risk
ORDER BY risk_category ASC;

--Clients PEP & Sanction Screening
select client_name, country, pep_flag, sanctions_flag   
from clients_with_fatf_ofac
where pep_flag = '1' or sanctions_flag = '1'
order by client_name asc;

--Sector Distribution Analysis
select sector, sector_risk, count(sector) as jumlah_nasabah
from clients_with_fatf_ofac
where sector_risk = 'High'
group by sector, sector_risk
order by jumlah_nasabah desc;

--Structuring Pattern Detection
select 
	transactions_with_fatf_ofac.client_id, clients_with_fatf_ofac.client_name,
	count(structuring_pattern_flag) as structured_transaction_count, 
	sum(amount) as total_amount
from transactions_with_fatf_ofac
inner join clients_with_fatf_ofac
on transactions_with_fatf_ofac.client_id = clients_with_fatf_ofac.client_id
where structuring_pattern_flag = 1
group by transactions_with_fatf_ofac.client_id, client_name
having structured_transaction_count > 1
order by total_amount desc;

--Highest Risk Clients Profiling
SELECT 
    clients_with_fatf_ofac.client_id,
    clients_with_fatf_ofac.client_name,
    clients_with_fatf_ofac.client_type,
    clients_with_fatf_ofac.country,
    clients_with_fatf_ofac.pep_flag,
    clients_with_fatf_ofac.sanctions_flag,
    clients_with_fatf_ofac.fatf_country_flag,
    clients_with_fatf_ofac.ofac_country_flag,
    (clients_with_fatf_ofac.pep_flag + clients_with_fatf_ofac.sanctions_flag + 
     clients_with_fatf_ofac.fatf_country_flag + clients_with_fatf_ofac.ofac_country_flag) AS risk_score,
    COUNT(transactions_with_fatf_ofac.transaction_id) AS total_transactions,
    SUM(transactions_with_fatf_ofac.amount) AS total_amount
FROM clients_with_fatf_ofac
JOIN transactions_with_fatf_ofac
    ON clients_with_fatf_ofac.client_id = transactions_with_fatf_ofac.client_id
GROUP BY 
    clients_with_fatf_ofac.client_id, clients_with_fatf_ofac.client_name, clients_with_fatf_ofac.client_type, clients_with_fatf_ofac.country,
    clients_with_fatf_ofac.pep_flag, clients_with_fatf_ofac.sanctions_flag, 
    clients_with_fatf_ofac.fatf_country_flag, clients_with_fatf_ofac.ofac_country_flag
HAVING risk_score >= 2
ORDER BY risk_score DESC, total_amount desc;

--Red Flag Clustering on Transactions Network
SELECT 
    transactions_with_fatf_ofac.client_country,
    transactions_with_fatf_ofac.counterparty_country,
    COUNT(transactions_with_fatf_ofac.transaction_id) AS total_transactions,
    SUM(transactions_with_fatf_ofac.amount) AS total_exposure,
    SUM(transactions_with_fatf_ofac.ofac_match_flag) AS ofac_count,
    SUM(transactions_with_fatf_ofac.structuring_pattern_flag) AS structuring_count,
    SUM(transactions_with_fatf_ofac.rapid_movement_flag) AS rapid_movement_count,
    SUM(transactions_with_fatf_ofac.trade_mispricing_flag) AS mispricing_count
FROM transactions_with_fatf_ofac
JOIN clients_with_fatf_ofac 
    ON transactions_with_fatf_ofac.client_id = clients_with_fatf_ofac.client_id
WHERE 
    (transactions_with_fatf_ofac.ofac_match_flag + 
    transactions_with_fatf_ofac.fatf_country_flag + 
    transactions_with_fatf_ofac.structuring_pattern_flag + 
    transactions_with_fatf_ofac.rapid_movement_flag + 
    transactions_with_fatf_ofac.trade_mispricing_flag) >= 2
GROUP BY transactions_with_fatf_ofac.client_country, transactions_with_fatf_ofac.counterparty_country, clients_with_fatf_ofac.sector_risk
ORDER BY total_exposure DESC;

--transactions type risk identification based on transactios type
select 
	transaction_type, 
	count(transaction_type) as total_transactions, 
	sum(amount) as total_amount,
	SUM(ofac_match_flag ) as total_match_flag,
	ROUND(COUNT(ofac_match_flag) * 100.0 / SUM(COUNT(ofac_match_flag)) OVER(), 2) AS OFAC_Match_Percentage
from transactions_with_fatf_ofac
group by transaction_type
order by ofac_match_percentage desc;

--Clients Rapid Fund Movement Identification
select 
	clients_with_fatf_ofac.client_name, 
	clients_with_fatf_ofac.pep_flag, 
	clients_with_fatf_ofac.sanctions_flag,
	COUNT(transactions_with_fatf_ofac.rapid_movement_flag) as rapid_movement_count,
	SUM(transactions_with_fatf_ofac.amount) as total_amount,
	avg(transactions_with_fatf_ofac.amount) as Average_amount
from transactions_with_fatf_ofac
inner join clients_with_fatf_ofac
on transactions_with_fatf_ofac.client_id = clients_with_fatf_ofac.client_id
where rapid_movement_flag = 1
group by clients_with_fatf_ofac.client_name, clients_with_fatf_ofac.pep_flag, clients_with_fatf_ofac.sanctions_flag
having rapid_movement_count > 3
order by total_amount desc;

--Country risk corridor
SELECT
    client_country,
    counterparty_country,
    COUNT(transaction_id) AS transactions_count,
    SUM(amount) AS total_exposure,
    SUM(ofac_match_flag) AS total_ofac_flag,
    SUM(fatf_country_flag) AS total_fatf_flag,
    SUM(rapid_movement_flag) AS total_rapid_count,
    (SUM(ofac_match_flag) + 
     SUM(fatf_country_flag) + 
     SUM(rapid_movement_flag)) AS total_red_flags
FROM transactions_with_fatf_ofac
GROUP BY client_country, counterparty_country
HAVING SUM(amount) > (SELECT AVG(corridor_total)
    FROM 
        (SELECT SUM(amount) AS corridor_total
        FROM transactions_with_fatf_ofac
        GROUP BY client_country, counterparty_country) AS corridor_avg)
ORDER BY total_red_flags DESC;


--corelation between ownership opacity and suspicious activity
select
CASE 
    WHEN ownership_opacity_score <= 0.3 THEN 'Low'
    WHEN ownership_opacity_score <= 0.7 THEN 'Medium'
    ELSE 'High'
END AS opacity_category,
	COUNT(clients_with_fatf_ofac.client_name) as client_count, 
	AVG(transactions_with_fatf_ofac.amount) as average_amount,
	SUM(transactions_with_fatf_ofac.amount) as total_amount
from clients_with_fatf_ofac
inner join transactions_with_fatf_ofac
on clients_with_fatf_ofac.client_id = transactions_with_fatf_ofac.client_id
group by opacity_category
order by total_amount desc;

--Identification on highest suspicious clients profile
select
	clients_with_fatf_ofac.client_name,
	(clients_with_fatf_ofac.pep_flag + 
	clients_with_fatf_ofac.sanctions_flag + 
	clients_with_fatf_ofac.fatf_country_flag + 
	clients_with_fatf_ofac.ofac_country_flag + 
	clients_with_fatf_ofac.sectoral_sanctions_flag) as clients_risk_score,
	SUM(transactions_with_fatf_ofac.ofac_match_flag + 
	transactions_with_fatf_ofac.structuring_pattern_flag + 
	transactions_with_fatf_ofac.rapid_movement_flag + 
	transactions_with_fatf_ofac.trade_mispricing_flag) as trasactions_risk_score,
	COUNT(transaction_id) as transactions_count, SUM(amount) as total_exposure,
	ownership_opacity_score 
from clients_with_fatf_ofac
inner join transactions_with_fatf_ofac
on clients_with_fatf_ofac.client_id = transactions_with_fatf_ofac.client_id
group by 
	clients_with_fatf_ofac.client_name,
	clients_with_fatf_ofac.pep_flag, 
	clients_with_fatf_ofac.sanctions_flag,
	clients_with_fatf_ofac.fatf_country_flag, 
	clients_with_fatf_ofac.ofac_country_flag,
	clients_with_fatf_ofac.sectoral_sanctions_flag, 
	transactions_with_fatf_ofac.ofac_match_flag, 
	transactions_with_fatf_ofac.structuring_pattern_flag, 
	transactions_with_fatf_ofac.rapid_movement_flag, 
	transactions_with_fatf_ofac.trade_mispricing_flag,
	ownership_opacity_score
having clients_risk_score >= 2 and trasactions_risk_score >= 2
order by clients_risk_score desc, total_exposure desc;

--Monthly Trend Analysis
select
    DATE_FORMAT(timestamp, '%Y-%M') AS month,
    COUNT(transaction_id) AS total_transactions,
    SUM(amount) AS total_amount,
    SUM(ofac_match_flag) AS total_ofac_flag,
    SUM(structuring_pattern_flag) AS total_structuring_transactions,
    SUM(rapid_movement_flag) AS total_rapid_transactions,
    ROUND(SUM(ofac_match_flag) * 100.0 / COUNT(*), 2) AS pct_suspicious
FROM transactions_with_fatf_ofac
GROUP BY month
ORDER BY month ASC;


