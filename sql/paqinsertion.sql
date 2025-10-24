USE [NGProd]
GO

/****** Object:  StoredProcedure [dbo].[csm_paq_insertion]    Script Date: 10/24/2025 2:38:39 PM ******/
DROP PROCEDURE [dbo].[csm_paq_insertion]
GO

/****** Object:  StoredProcedure [dbo].[csm_paq_insertion]    Script Date: 10/24/2025 2:38:39 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




-- =============================================
-- Author:		<Logan Thomas>
-- Create date: <05/21/2021>
-- Description:	<Inject appropriate PAQ access for New provider>
-- =============================================
CREATE PROCEDURE [dbo].[csm_paq_insertion]
	-- Add the parameters for the stored procedure here
 @user_id INT
,@npi VARCHAR(12)
    
AS
BEGIN

	DECLARE @provider_count INT = (SELECT COUNT(*) FROM provider_mstr WHERE national_provider_id = @npi AND provider_type_pcp_ind = 'N');
		IF @provider_count = 1
			BEGIN
				DECLARE @provider_user INT = (SELECT DISTINCT user_id
										FROM user_mstr
											WHERE provider_id IN (
												SELECT DISTINCT p.provider_id 
													FROM provider_mstr p
														JOIN user_provider_xref px ON p.provider_id=px.provider_id
														JOIN user_provider_relationship pr ON px.relationship_id=pr.relationship_id AND pr.relationship_desc = 'Self'
														JOIN provider_practice_mstr pp ON p.provider_id=pp.provider_id AND pp.attending_ind = 'Y'
															WHERE p.delete_ind = 'N'
																AND p.provider_type_pcp_ind = 'N'
																AND p.national_provider_id = @npi
																)
										);
				DECLARE @location VARCHAR(36) = (SELECT location_id FROM location_mstr WHERE location_id= (SELECT primary_loc_id FROM provider_mstr WHERE national_provider_id = @npi AND provider_type_pcp_ind = 'N'));
			END
	
	DECLARE @delegatecount INT = (SELECT COUNT(delegate_user_id) FROM [dbo].[workflow_prov_delegates] WHERE provider_id IN (SELECT DISTINCT provider_id FROM csm_paq_location_xref WHERE paq_market IN (SELECT paq_market FROM csm_paq_location_xref WHERE ng_location_id=@location)) AND delegate_user_id=@provider_user)	
		IF @delegatecount = 0
			BEGIN
				INSERT INTO [dbo].[workflow_prov_delegates](
							[practice_id]
				           ,[provider_id]
				           ,[delegate_user_id]
				           ,[delegate_provider_ind]
				           ,[display_paq_ind]
				           ,[display_workflow_ind]
				           ,[paq_use_always_ind]
				           ,[workflow_use_always_ind]
				           ,[documents_ind]
				           ,[images_ind]
				           ,[notes_ind]
				           ,[ics_ind]
				           ,[labs_ind]
				           ,[tasks_ind]
				           ,[created_by]
				           ,[modified_by]
				           ,[create_timestamp]
				           ,[modify_timestamp]
				           ,[reports_ind]
				           ,[hie_documents_ind]
				           ,[portal_ind])
				 
				SELECT DISTINCT 
						 c.practice_id
						,c.provider_id
						,@provider_user
						,'Y'
						,'Y'
						,'N'
						,'Y'
						,'N'
						,'Y'
						,'Y'
						,'Y'
						,'Y'
						,'Y'
						,'Y'
						,@user_id
						,@user_id
						,GETDATE()
						,GETDATE()
						,'Y'
						,'Y'
						,'Y'
						
					FROM [dbo].[csm_paq_location_xref] c
							WHERE c.paq_market LIKE (SELECT paq_market FROM csm_paq_location_xref WHERE ng_location_id=@location)
			END
END
GO


