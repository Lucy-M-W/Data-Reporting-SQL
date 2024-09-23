-- customers transaction count

select count(o.id) as counts
 from loginsdb.outbound_transactions o LEFT JOIN loginsdb.logintable l on o.customer_ID=l.account 
 where o.status='PROCESSED' AND MONTH(o.createdAt) =6 AND YEAR(o.createdAt) = 2018;
 
 -- customers yet to transact
 
 select l.First_Name as name ,l.email,concat('"+254',substr(l.mobile,-9),'"') as mobile,if(l.c_pin!="",if(l.uploadpin!="",1,0),0) as KYC, if(l.account in (SELECT customer_ID FROM loginsdb.outbound_transactions where status = 'PROCESSED' group by customer_ID having count(*) > 0),1,0) as TXN

FROM loginsdb.logintable l where mobile != "" and first_name != "1" and l.level =2 order by txn desc, kyc desc;


-- FPESA transaction volume report

select *
FROM
(SELECT  DATE_FORMAT(createdAt, "%M %Y") As Period, rate * amount AS Transactions_Volume,
 (rate*amount)/100*0.5 As Revenue 

FROM  loginsdb.outbound_transactions  

Where createdAt between '2017/01/01' and current_date() and amount >=' 1'
GROUP BY date_format(createdAt, "%M %Y") 

order by createdAt asc

) as Y;

--  FPESA subscribers

select count(distinct customer_ID)as registrations, unix_timestamp(createdAt),DATE_FORMAT(createdAt, '%Y %M') AS period
from outbound_transactions

GROUP BY YEAR(createdAt), MONTH(createdAt);


-- JBB quatation turnaround time

SELECT

count(*) as quote_request, sum(Total_KES_value) AS Total_KES_value, sum(quoted) As Quoted, 
sum(No_of_cancelled_transactions) AS No_of_cancelled_transactions , sum(No_of_wins) AS No_of_wins,sum(Total_KES_wins) as Total_KES_wins,
count(*) -sum(No_of_cancelled_transactions)- sum(No_of_wins) AS Loses,count(*)- sum(quoted)-sum(No_of_cancelled_transactions) AS Unquoted, 
sum(Total_KES_value) - sum(Total_KES_wins) as Total_remaining_wins  
from
(SELECT 
lc.code, lc.exchange_rate, r.status as request_status, q.status as quote_status, r.amount, q.rate, q.LASTCHANGEBY, r.id,
if(CONVERT(q.rate,UNSIGNED INTEGER) > 0,
if(q.LASTCHANGEBY is null,1,0),0) as quoted, if(r.status='STLD', r.amount * ROUND(lc.exchange_rate,2) , '0')AS Total_KES_value, 
if(r.status in ('CNCD','DONE','OPEN'), '1', '0') AS No_of_cancelled_transactions, 
if(q.status='STLD', '1', '0') AS No_of_wins, if(q.status='STLD', r.amount * q.rate, '0') AS Total_KES_wins,
if(r.status='STLD',1,0) as Lost   

FROM forexcoke03.t_request r LEFT JOIN 

(SELECT q.rate, q.status, q.LASTCHANGEBY, q.REQUEST_ID_OID FROM forexcoke03.t_quote q 
LEFT JOIN forexcoke03.t_dealeruser p ON p.id = q.DEALERUSER_ID_OID 
LEFT JOIN forexcoke03.t_dealerparty dp ON dp.id = p.DEALERPARTY_ID_OID WHERE dp.BANK_ABBR = 'JBB') q ON q.REQUEST_ID_OID = r.ID

LEFT JOIN t_currency c ON c.id = r.CURRENCY_ID_OID
LEFT JOIN loginsdb.currency lc ON c.CODE = lc.code
where 
r.POSTEDTIME < UNIX_TIMESTAMP(now())*1000 and r.POSTEDTIME > UNIX_TIMESTAMP(date_sub(now(), interval 6 month))*1000

order by r.id desc) 
as B;


-- Bargain of the Week report

SELECT currency, updatedAt, 
round(if(currency='USD',exchange_rate-3,if (currency='GBP', exchange_rate-4, if (currency='EUR', exchange_rate-5, 0))),2) as BUY,
round(if(currency='USD',exchange_rate+3,if (currency='GBP', exchange_rate+4, if (currency='EUR', exchange_rate+5, 0))),2) as SELL 
from exchange_rates_history WHERE DATEDIFF(NOW(),updatedAt) < 8 and DATEDIFF(NOW(),updatedAt) > 2;


-- P & L transcation

SELECT

sum(case when side="Buy" then amount else 0 end) - sum(case when side="Sell" then amount else 0 end) * avg(buy_rate) as Opening_stock_V,
sum(case when side="Buy" then amount else 0 end) - sum(case when side="Sell" then amount else 0 end) as Opening_stock,
sum(sells_value) as SellsV,
sum(buys_value)as BuysV,
avg(buy_rate) as ACP, 
avg(sell_rate) as ASP,
sum(all_buys) as Buys ,
sum(all_sells) as Sells, 
sum(all_buys) - sum(all_sells) + sum(all_buys) - sum(all_sells) as Current_stock,
(sum(all_sells) - sum(all_buys)) * (avg(sell_rate) - avg(buy_rate))  as Unrealised_Profit,

sum(all_buys)*avg(buy_rate) - sum(all_sells) * avg(sell_rate) as P_L,
(sum(all_buys) - sum(all_sells) + sum(all_buys) - sum(all_sells)) * avg(buy_rate) as Closing_stock_V,
sum(all_buys) - sum(all_sells) + sum(all_buys) - sum(all_sells) as Closing_stock

FROM (

select bank_ID,createdAt,rate,side,amount,

if(side='Sell', amount,'0') AS all_sells,
if(side='Buy', amount,'0') AS all_buys,
if(side='Buy', rate,'0') AS buy_rate,
if(side='Sell', rate,'0') AS sell_rate,
if(side='Sell', rate*amount,'0') AS sells_value,
if(side='Buy', rate*amount,'0') AS buys_value
from loginsdb.otc

where bank_ID='212' 
#and createdAt > concat(year(now()),"-", lpad(month(now()),2,'0'),"-", lpad(day(now()),2,'0')," 09:00:00")

)
as Q;


-- Customers quatation turnaround time report

SELECT
count(*) as quote_request, sum(Total_KES_value) AS Total_KES_value, sum(quoted) As Quoted, 
sum(No_of_cancelled_transactions) AS No_of_cancelled_transactions , sum(No_of_wins) AS No_of_wins,
count(*) -sum(No_of_cancelled_transactions)- sum(No_of_wins) AS loses,count(*)- sum(quoted)-sum(No_of_cancelled_transactions) AS Unquoted, 
sum(Total_KES_value) - sum(Total_KES_wins) as Total_KES_wins 
from
(SELECT 
lc.code, lc.exchange_rate, r.status as request_status, q.status as quote_status, r.amount, q.rate, q.LASTCHANGEBY, r.id,
if(CONVERT(q.rate,UNSIGNED INTEGER) > 0,
if(q.LASTCHANGEBY is null,1,0),0) as quoted, r.amount * lc.exchange_rate AS Total_KES_value, 
if(r.status in ('CNCD','DONE','OPEN'), '1', '0') AS No_of_cancelled_transactions, 
if(q.status='STLD', '1', '0') AS No_of_wins, if(q.status='STLD', r.amount * q.rate, '0') AS Total_KES_wins 

FROM forexcoke03.t_request r LEFT JOIN 

(SELECT q.rate, q.status, q.LASTCHANGEBY, q.REQUEST_ID_OID FROM forexcoke03.t_quote q 
LEFT JOIN forexcoke03.t_dealeruser p ON p.id = q.DEALERUSER_ID_OID 
LEFT JOIN forexcoke03.t_dealerparty dp ON dp.id = p.DEALERPARTY_ID_OID WHERE dp.BANK_ABBR = 'ABC') q ON q.REQUEST_ID_OID = r.ID

LEFT JOIN t_currency c ON c.id = r.CURRENCY_ID_OID
LEFT JOIN loginsdb.currency lc ON c.CODE = lc.code
where 
r.POSTEDTIME < UNIX_TIMESTAMP(now())*1000 and r.POSTEDTIME > UNIX_TIMESTAMP(date_sub(now(), interval 1 month))*1000

order by r.id desc) 
as A;

-- Transaction time delay for bank transctions

create view time_delay_compliance_abc as
SELECT concat(l.First_Name, ' ' , l.surname) as name,l.email,timestampdiff(day, (SELECT s.updatedAt),now()) as Delay,s.user_ID
 FROM loginsdb.logintable l LEFT JOIN loginsdb.onsiteupdates s on s.user_id=l.id 
 where s.bank = 210
order by delay DESC 
limit 25;
 
-- Total customer transactions


select *, sum(Transactions_amount) as Total_Amount

FROM
(SELECT   rate * amount AS Transactions_amount
 
FROM  loginsdb.outbound_transactions  
Where createdAt between '2016/01/01' and current_date() 

order by createdAt asc

) as Y;

-- Individual customer processed transaction

use loginsdb;
select count(*), concat(month(createdAt),"-",year(createdAt)), sum(amount*rate )
from outbound_transactions 
where 
status = "PROCESSED" and 
customer_ID in (Select account from logintable) group by concat(month(createdAt),"-",year(createdAt));

-- Transaction summary

 SELECT  DATE_FORMAT(createdAt, "%M %Y") As createdAt,currency, sum(Volume) AS Volume
 FROM
 
 (SELECT createdAt,currency, rate*amount AS Volume
FROM outbound_transactions

WHERE YEAR(createdAt) = 2018


and status='PROCESSED'
)
as T

GROUP BY date_format(createdAt, "%M"),currency
ORDER BY date_format(createdAt, "%M");

-- Transaction volume

 SELECT  DATE_FORMAT(createdAt, "%M %Y") As createdAt,currency, sum(Volume) AS Volume,sum(0.005*Volume) AS Commission
 FROM
 
 (SELECT createdAt,currency, rate*amount AS Volume
FROM outbound_transactions

WHERE YEAR(createdAt) = YEAR(CURRENT_DATE - INTERVAL 2 MONTH)
AND MONTH(createdAt) = MONTH(CURRENT_DATE - INTERVAL 2 MONTH)

and status='PROCESSED'
)
as T

group by currency;


































 
 
 
 
 
 
 
 
 
 
 
 
 
 