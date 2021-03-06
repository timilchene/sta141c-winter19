-- From the original Postgres usaspending database

-- How was the original view made?
-- https://dba.stackexchange.com/questions/102620/query-the-definition-of-a-materialized-view-in-postgres
-- psql -c "SELECT definition FROM pg_matviews WHERE matviewname = 'universal_transaction_matview';" > universal_transaction_matview.sql

  SELECT to_tsvector(concat_ws(' '::text, COALESCE(recipient_lookup.recipient_name, transaction_fpds.awardee_or_recipient_legal, transaction_fabs.awardee_or_recipient_legal), transaction_fpds.naics, naics.description, psc.description, transaction_normalized.description)) AS keyword_ts_vector,
     to_tsvector(concat_ws(' '::text, awards.piid, awards.fain, awards.uri)) AS award_ts_vector,
     to_tsvector(COALESCE(recipient_lookup.recipient_name, transaction_fpds.awardee_or_recipient_legal, transaction_fabs.awardee_or_recipient_legal)) AS recipient_name_ts_vector,
     transaction_normalized.id AS transaction_id,
     transaction_normalized.action_date,
     transaction_normalized.last_modified_date,
     transaction_normalized.fiscal_year,
     transaction_normalized.type,
     transaction_normalized.action_type,
     transaction_normalized.award_id,
     awards.category AS award_category,
     (COALESCE(
         CASE
             WHEN (awards.category = 'loans'::text) THEN awards.total_subsidy_cost
             ELSE transaction_normalized.federal_action_obligation
         END, (0)::numeric))::numeric(23,2) AS generated_pragmatic_obligation,
     awards.total_obligation,
     awards.total_subsidy_cost,
     awards.total_loan_value,
     obligation_to_enum(awards.total_obligation) AS total_obl_bin,
     awards.fain,
     awards.uri,
     awards.piid,
     (COALESCE(transaction_normalized.federal_action_obligation, (0)::numeric))::numeric(20,2) AS federal_action_obligation,
     (COALESCE(transaction_normalized.original_loan_subsidy_cost, (0)::numeric))::numeric(20,2) AS original_loan_subsidy_cost,
     (COALESCE(transaction_normalized.face_value_loan_guarantee, (0)::numeric))::numeric(23,2) AS face_value_loan_guarantee,
     transaction_normalized.description AS transaction_description,
     transaction_normalized.modification_number,
     place_of_performance.location_country_code AS pop_country_code,
     place_of_performance.country_name AS pop_country_name,
     place_of_performance.state_code AS pop_state_code,
     place_of_performance.county_code AS pop_county_code,
     place_of_performance.county_name AS pop_county_name,
     place_of_performance.zip5 AS pop_zip5,
     place_of_performance.congressional_code AS pop_congressional_code,
         CASE
             WHEN (COALESCE(transaction_fpds.legal_entity_country_code, transaction_fabs.legal_entity_country_code) = 'UNITED STATES'::text) THEN 'USA'::text
             ELSE COALESCE(transaction_fpds.legal_entity_country_code, transaction_fabs.legal_entity_country_code)
         END AS recipient_location_country_code,
     COALESCE(transaction_fpds.legal_entity_country_name, transaction_fabs.legal_entity_country_name) AS recipient_location_country_name,
     COALESCE(transaction_fpds.legal_entity_state_code, transaction_fabs.legal_entity_state_code) AS recipient_location_state_code,
     COALESCE(transaction_fpds.legal_entity_county_code, transaction_fabs.legal_entity_county_code) AS recipient_location_county_code,
     COALESCE(transaction_fpds.legal_entity_county_name, transaction_fabs.legal_entity_county_name) AS recipient_location_county_name,
     COALESCE(transaction_fpds.legal_entity_congressional, transaction_fabs.legal_entity_congressional) AS recipient_location_congressional_code,
     COALESCE(transaction_fpds.legal_entity_zip5, transaction_fabs.legal_entity_zip5) AS recipient_location_zip5,
     transaction_fpds.naics AS naics_code,
     naics.description AS naics_description,
     transaction_fpds.product_or_service_code,
     psc.description AS product_or_service_description,
     transaction_fpds.pulled_from,
     transaction_fpds.type_of_contract_pricing,
     transaction_fpds.type_set_aside,
     transaction_fpds.extent_competed,
     transaction_fabs.cfda_number,
     references_cfda.program_title AS cfda_title,
     transaction_normalized.recipient_id,
     COALESCE(recipient_lookup.recipient_hash, (md5(upper(COALESCE(transaction_fpds.awardee_or_recipient_legal, transaction_fabs.awardee_or_recipient_legal))))::uuid) AS recipient_hash,
     upper(COALESCE(recipient_lookup.recipient_name, transaction_fpds.awardee_or_recipient_legal, transaction_fabs.awardee_or_recipient_legal)) AS recipient_name,
     COALESCE(transaction_fpds.awardee_or_recipient_uniqu, transaction_fabs.awardee_or_recipient_uniqu) AS recipient_unique_id,
     COALESCE(transaction_fpds.ultimate_parent_unique_ide, transaction_fabs.ultimate_parent_unique_ide) AS parent_recipient_unique_id,
     legal_entity.business_categories,
     transaction_normalized.awarding_agency_id,
     transaction_normalized.funding_agency_id,
     taa.name AS awarding_toptier_agency_name,
     tfa.name AS funding_toptier_agency_name,
     saa.name AS awarding_subtier_agency_name,
     sfa.name AS funding_subtier_agency_name,
     taa.abbreviation AS awarding_toptier_agency_abbreviation,
     tfa.abbreviation AS funding_toptier_agency_abbreviation,
     saa.abbreviation AS awarding_subtier_agency_abbreviation,
     sfa.abbreviation AS funding_subtier_agency_abbreviation
    FROM (((((((((((((((transaction_normalized
      LEFT JOIN transaction_fabs ON (((transaction_normalized.id = transaction_fabs.transaction_id) AND (transaction_normalized.is_fpds = false))))
      LEFT JOIN transaction_fpds ON (((transaction_normalized.id = transaction_fpds.transaction_id) AND (transaction_normalized.is_fpds = true))))
      LEFT JOIN references_cfda ON ((transaction_fabs.cfda_number = references_cfda.program_number)))
      LEFT JOIN legal_entity ON ((transaction_normalized.recipient_id = legal_entity.legal_entity_id)))
      LEFT JOIN ( SELECT rlv.recipient_hash,
             rlv.legal_business_name AS recipient_name,
             rlv.duns
            FROM recipient_lookup rlv) recipient_lookup ON (((recipient_lookup.duns = COALESCE(transaction_fpds.awardee_or_recipient_uniqu, transaction_fabs.awardee_or_recipient_uniqu)) AND (COALESCE(transaction_fpds.awardee_or_recipient_uniqu, transaction_fabs.awardee_or_recipient_uniqu) IS NOT NULL))))+
      LEFT JOIN awards ON ((transaction_normalized.award_id = awards.id)))
      LEFT JOIN references_location place_of_performance ON ((transaction_normalized.place_of_performance_id = place_of_performance.location_id)))
      LEFT JOIN agency aa ON ((transaction_normalized.awarding_agency_id = aa.id)))
      LEFT JOIN toptier_agency taa ON ((aa.toptier_agency_id = taa.toptier_agency_id)))
      LEFT JOIN subtier_agency saa ON ((aa.subtier_agency_id = saa.subtier_agency_id)))
      LEFT JOIN agency fa ON ((transaction_normalized.funding_agency_id = fa.id)))
      LEFT JOIN toptier_agency tfa ON ((fa.toptier_agency_id = tfa.toptier_agency_id)))
      LEFT JOIN subtier_agency sfa ON ((fa.subtier_agency_id = sfa.subtier_agency_id)))
      LEFT JOIN naics ON ((transaction_fpds.naics = naics.code)))
      LEFT JOIN psc ON ((transaction_fpds.product_or_service_code = (psc.code)::text)))
   WHERE (transaction_normalized.action_date >= '2000-10-01'::date)
   ORDER BY transaction_normalized.action_date DESC;
