-- ==============================
-- Run this first portion to create the provider in File Maintenance 
-- Once finished - Check in File Maintenance
-- Comment out Stored Procedure run to use the variable again in the next block
-- ==============================
/* --List of provider types:
Nurse Practitioners
Physician Assistants
Physicians 

--Run this to see location names:
SELECT lm.location_name, ml.mstr_list_item_desc FROM location_mstr lm join mstr_lists ml ON ml.mstr_list_item_id = lm.location_subgrouping1_id
WHERE ml.mstr_list_item_desc like '%FL' AND lm.delete_ind = 'N' ORDER by 1, 2
*/

--select * from location_mstr order by location_name

DECLARE @first_name VARCHAR(25) = 'Syuzanna';
DECLARE @last_name VARCHAR(25) = 'Mecca';
DECLARE @degree VARCHAR(15) = 'APRN';
DECLARE @npi VARCHAR(15) = '1184460370';
DECLARE @dea_nbr VARCHAR(15) = 'MM9860962';
DECLARE @lic_nbr VARCHAR(50) = 'APRN11034095';
DECLARE @subgrouping2 VARCHAR(36) = (SELECT mstr_list_item_id FROM mstr_lists WHERE mstr_list_item_desc like 'Nurse Prac%' AND mstr_list_type = 'provider_subgrouping');
DECLARE @location UNIQUEIDENTIFIER = (SELECT DISTINCT location_id FROM location_mstr WHERE location_name LIKE 'St Augustin%');
DECLARE @tax  VARCHAR(36) = (SELECT taxonomy_id FROM taxonomy_mstr tm WHERE tm.taxonomy_code = '363LF0000X');
DECLARE @user INT = 997;


--exec csm_prov_add_fm @first_name=@first_name,@last_name=@last_name,@degree=@degree,@npi=@npi,@dea_nbr=@dea_nbr,@lic_nbr=@lic_nbr,@subgrouping2=@subgrouping2,@location_id=@location,@user_id=@user,@taxonomy=@tax


-- ==============================
-- Create the user in System Administrator with provider assigned and set to 'Self' Relationship
-- Sign off for PAQ in System Administrator
-- Add the provider to the correct Task Workgroup in File Maintenance
-- Enroll in eRX in File Maintenance and add Supervising Physician
-- ==============================


DECLARE @current VARCHAR(36) = 'F441FEEE-4EF6-4581-B0DC-488DBD01E634';
DECLARE @new VARCHAR(36) = (SELECT provider_id FROM provider_mstr WHERE national_provider_id = @npi);
DECLARE @new_user int = (SELECT DISTINCT user_id
							FROM user_mstr
								WHERE provider_id IN (
									SELECT DISTINCT p.provider_id 
										FROM provider_mstr p
											JOIN user_provider_xref px ON p.provider_id=px.provider_id
											JOIN user_provider_relationship pr ON px.relationship_id=pr.relationship_id AND pr.relationship_desc = 'Self'
											JOIN provider_practice_mstr pp ON p.provider_id=pp.provider_id AND pp.attending_ind = 'Y'
												WHERE p.delete_ind = 'N'
													AND provider_type_pcp_ind = 'N'
													AND p.national_provider_id =  @npi
													)
						);

--Set variables for Stored Procedures
DECLARE @new_user_name VARCHAR(35) = (SELECT first_name+' '+last_name FROM user_mstr WHERE user_id = @new_user)
DECLARE @practice CHAR(4) = (SELECT practice_id FROM csm_paq_location_xref where ng_location_id=@location)

--Check to make sure variables are set correctly
SELECT @new_user,@practice,(SELECT location_name FROM location_mstr WHERE location_id=@location) as home_center,@new_user_name, (SELECT provider_id from provider_mstr where national_provider_id = @npi)


--Copy payers, contracts, phrases and inject the provider user account into PAQ delegate table, and copy the med faves to the new provider user account
	BEGIN
		EXEC sol_copy_provider_contracts @practice_id=@practice, @current_Provider_id = @current,@New_Provider_id=@new, @user_id=@user;
		EXEC sol_copy_provider_payers @practice_id=@practice, @current_Provider_id = @current,@New_Provider_id=@new, @user_id=@user;
		EXEC CSP_My_Phrases_SP @user_name=@new_user_name,@user_id=@new_user,@entity = 'All',@type = 'All';
		EXEC csm_paq_insertion @user_id=@user,@npi=@npi;
		EXEC csm_prov_copy_meds @user_id=@user,@npi=@npi;
		
	END 


/**********File Maintenance Rollback**************
select p.provider_id
		,p.description
		,(SELECT FORMAT(COUNT(*),'N0') FROM provider_practice_payers WHERE provider_id=p.provider_id and practice_id=pp.practice_id) payers
		,(SELECT FORMAT(COUNT(*),'N0') FROM contract_links WHERE provider_id=p.provider_id and practice_id=pp.practice_id) AS contracts
		--,(SELECT FORMAT(COUNT(*),'N0') FROM ngkbm_my_phrases_ WHERE userID=um.user_id) as phrases 

from provider_mstr p
	join provider_practice_mstr pp on p.provider_id=pp.provider_id
		
	where description like 'dawkins pa%'
		group by p.provider_id
				,p.description
				,pp.practice_id

DECLARE @provider varchar(36) = 'E7748A6C-5837-4B64-8A6E-322370530CE8'
delete from provider_mstr where provider_id = @provider
delete from provider_practice_mstr where provider_id = @provider
delete from practice_mstr_files where mstr_file_id = @provider
delete from erx_provider_mstr where provider_id = @provider
delete from provider_practice_types where provider_id = @provider
delete from erx_provider_tasking where provider_id = @provider
delete from license_detail where limit_value = @provider
**********File Maintenance Rollback**************/