--Цель анализа - выявить основные факторы, которые влияют на активность доноров

--Определяем регионы с наибольшим количеством зарегистрированных пользователей
SELECT 
	region,
	COUNT(id) AS count_donors,
	ROUND(COUNT(id) * 1.0 / (SELECT COUNT(id) FROM donorsearch.user_anon_data) * 100) AS percent_donors
FROM donorsearch.user_anon_data
GROUP BY region
ORDER BY count_donors DESC
LIMIT 5;
--38% пользователей не указало город, что стоит исправить
--наибольшее количество доноров в крупных городах

--Изучаем динамику количества донаций в месяц за 2022 и 2023 год
WITH 
month_count AS(
SELECT 
	DATE_TRUNC('month', donation_date)::date AS month,
	COUNT(id) AS count_donations
FROM donorsearch.donation_anon 
WHERE donation_date BETWEEN '2022-01-01' AND '2023-12-31'
GROUP BY month
ORDER BY month)
SELECT
	month,
	count_donations,
	ROUND((count_donations - LAG(count_donations) OVER()) / LAG(count_donations) OVER()::NUMERIC * 100) percent_definition_per_month
FROM month_count
--В 2022 году наблюдается рост активности доноров, в 2023 - спад
--Также стоит обратить внимание на регулярный спад активности в мае

--Определяем наиболее активных доноров в системе
SELECT 
	id,
	confirmed_donations
FROM donorsearch.user_anon_data
ORDER BY confirmed_donations DESC
LIMIT 10;
--Наиболее активные доноры показывают большую степень вовлечённости
--В сравнении со средним количеством донаций на пользоватлея - 1, результаты наимболее активных сильно выделяются
--Иммет смысл выделять активных пользоваталей в отдельные категории для применения особых стратегий по мотивации

--Оценим, как система бонусов влияет на донации
SELECT
	CASE
		WHEN user_bonus_count > 0 THEN 'Получали бонусы'
		ELSE 'Не получали бонусы'
	END AS category,
	COUNT(u.id) AS count_donors,
	ROUND(AVG(confirmed_donations), 1) AS avg_count_donations
FROM donorsearch.user_anon_data u
LEFT JOIN donorsearch.user_anon_bonus b ON u.id = b.user_id
GROUP BY category;
--Большинство доноров не получали бонусы (256 491) и совершили мало донаций  - в среднем 0,5
--При этом те, что получали бонусы (21 108) совершили значительно больше донаций  - в среднем 13,9
--Подобная статистика говорит о чильном влиянии системы бонусов на мотивацию доноров

--Исследуем вовлечение новых доноров через социальные сети
--Будем учитывать только тех, кто совершил хотя бы одну донацию
SELECT
	CASE 
		WHEN autho_vk THEN 'ВКонтакте'
		WHEN autho_ok THEN 'Одноклассники'
		WHEN autho_tg THEN 'Телеграм'
		WHEN autho_yandex THEN 'Яндекс'
		WHEN autho_google THEN 'Гугл'
		ELSE 'Нет авторизации через социальные сети'
	END AS social_media,
	COUNT(id) AS count_donors,
	ROUND(COUNT(id)::numeric / (SELECT COUNT(id) FROM donorsearch.user_anon_data WHERE confirmed_donations > 0), 3) AS donors_part,
	ROUND(AVG(confirmed_donations), 3) AS avg_donations
FROM donorsearch.user_anon_data
WHERE confirmed_donations > 0
GROUP BY social_media
ORDER BY count_donors DESC;
--Более трети пользователей не авторизованы через социальные сети (34,8%), такие пользователи показывают средний уровень активности донаций (5,965)
--Среди социальных сетей наиболее популярна ВКонтакте (54,1%), более половины доноров используют именно ее, при этом активность донаций также средняя (5,558)
--Гугл и Одноклассники также показывают средний уровень вовлечённости - 6,047 и 5,559 донаций в среднем соответственно
--Наиболее активные доноры авторизованы через Яндекс (7,043 донаций в среднем), при этом такие доноры составляют всего 2,6%
--Наименее популярная соцсеть среди доноров - Телеграм (0,3%), такие пользователи также показывают низкий уровень вовлечённости - 4,829 донаций в среднем

--Сравним активность однократных доноров со средней активностью повторных доноров
WITH user_stat AS(
SELECT 
	user_id,
	COUNT(id) AS donation_count,
	MAX(donation_date) - MIN(donation_date) AS days_between_first_and_last,
	CASE WHEN COUNT(id) > 1 THEN
		(MAX(donation_date) - MIN(donation_date)) / (COUNT(id) - 1)
	END AS days_between_donation
FROM donorsearch.donation_anon
WHERE EXTRACT(YEAR FROM donation_date) >= 1970 --Исключаем аномальные данные
GROUP BY user_id)
SELECT 
	CASE 
		WHEN donation_count = 1 THEN '1 донация'
		WHEN donation_count BETWEEN 2 AND 3 THEN '2-3 донации'
		WHEN donation_count BETWEEN 4 AND 5 THEN '4-5 донаций'
		ELSE '6 и более донаций'
	END AS count_group,
	COUNT(user_id) AS count_users,
	ROUND(COUNT(user_id)::numeric / (SELECT COUNT(user_id) FROM user_stat) * 100) AS user_percent,
	ROUND(AVG(donation_count), 2) AS avg_donation_count,
	AVG(days_between_first_and_last)::int AS avg_days_activity,--среднее количество дней между первой и последней донацией
	AVG(days_between_donation)::int AS avg_days_between_donation--среднее количество дней между донациями
FROM user_stat 
GROUP BY count_group
ORDER BY count_group;
--53% доноров, то есть большая часть, совершили донацию всего 1 раз
--21% совершили 2-3 донации, при этом между первой и последней в среднем проходило 322 дня, а между донациями - 248 дней
--8% совершили 4-5 донаций, при этом между первой и последней в среднем проходило 663 дня, а между донациями - 195 дней
--19% совершили 6 и более донаций, при этому между первой и последней в среднем проходило 2248 дней, а между донациями - 142 дня
--Так, чем больше донаций совершают люди, тем меньше время между донациями; повторные доноры остаются активными дольше

--Сравним данные о планируемых донациях с фактическими данными
SELECT 
	dp.donation_type,
	COUNT(dp.id) AS count_plan_donations,
	SUM(CASE WHEN da.user_id IS NOT NULL THEN 1 ELSE 0 END) AS count_completed_donations,
	ROUND(SUM(CASE WHEN da.user_id IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(dp.id), 1) AS completed_percent 
FROM donorsearch.donation_plan dp
LEFT JOIN donorsearch.donation_anon da ON dp.user_id = da.user_id AND dp.donation_date = da.donation_date
GROUP BY dp.donation_type;
--Процент выполнения планируемых донаций низок как для безвозмездных - 21,7%, так и для платных - 13,2%
--Важно улучшить систему мотивации доноров, в особенности тех, кто уже запланировал донацию

--Проведём анализ пользователей, в зависимости от возраста и пола
SELECT
	CASE 
		WHEN date_part('year', age(birth_date)) BETWEEN 18 AND 20 THEN '18-20 лет'
		WHEN date_part('year', age(birth_date)) BETWEEN 21 AND 30 THEN '21-30 лет'
		WHEN date_part('year', age(birth_date)) BETWEEN 31 AND 40 THEN '31-40 лет'
		WHEN date_part('year', age(birth_date)) BETWEEN 41 AND 50 THEN '41-50 лет'
		WHEN date_part('year', age(birth_date)) BETWEEN 51 AND 60 THEN '51-60 лет'
		WHEN date_part('year', age(birth_date)) > 60 THEN 'более 60'
		ELSE 'нет данных'
	END AS age_donor,
	gender,
	COUNT(id) AS count_donors,
	ROUND(COUNT(id) * 100.0 / (SELECT COUNT(id) FROM donorsearch.user_anon_data), 3) AS donor_percent,
	ROUND(AVG(confirmed_donations), 2) AS avg_donations,
	SUM(CASE WHEN confirmed_donations = 1 THEN 1 ELSE 0 END) AS one_time_donors,
    SUM(CASE WHEN confirmed_donations > 1 THEN 1 ELSE 0 END) AS repeat_donors,
    SUM(CASE WHEN confirmed_donations > 1 THEN 1 ELSE 0 END) * 100 / SUM(CASE WHEN confirmed_donations >= 1 THEN 1 ELSE 0 END) AS repeat_donors_percent
FROM donorsearch.user_anon_data
GROUP BY age_donor, gender
ORDER BY repeat_donors_percent DESC;
--Большинство пользователей (61%) не указывают информацию о поле и возрасте, что негативно сказывается на качестве данных, становится сложнее понять пользователей
--Наибольшее количество доноров - женщины 21-30 лет (9%), мужчины 31-40 лет(6%), женщины 31-40 лет (6%), мужчины 21-30 лет (6%)
--Наибольшее количество донаций в среднем совершают мужчины 41-50 лет (2,98), мужчины 31-40 лет (2,92)
--Повторными донорами чаще других являются мужчины 51-60 лет (75%), мужчины 41-50 лет(70%), реже других повторно становятся донорами женщины 18-20 лет (44%)
/*
 * Итог:
 * В данных больше количество аномальных и пропущенных значений
 * Наибольшее количество доноров находится в крупных городах, значит стоит улучшить систему мотивации для регионов
 * В донорстве наблюдается сезонность - в конце весны - начале лета активность идет на спад 
 * В программе есть доноры с большим количеством донаций, сильно отличающемся от среднего
 * Система бонусов успешно мотивирует пользователей на донорство, те, что получали бонусы превыщают показатели оставшейся части почти в 7 раз
 * Пользователи активно авторизуются через соцсети, особенно через ВКонтакте
 * Однократных доноров большинство - 53% , при этом повторные доноры делают большее количество донаций и остаются активными дольше
 * Пользователи выполняют запланированную донацию в 22% для безвозмедных доноров и в 13% для платных доноров, следует улучшить стратегию мотивации таких пользователей
 * Среди доноров преобладают женщины 21-30 лет (9%), мужчины 31-40 лет(6%), женщины 31-40 лет (6%), мужчины 21-30 лет (6%), при этом мужчины в среднем совершают большее количество повторных донаций
 */
