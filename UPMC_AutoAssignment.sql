USE [tmsenterprise]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
 =============================================
 Author:		Colby King
 Date Created:	10.21.2020
 Description:	
 =============================================
 */
CREATE PROCEDURE [dbo].[spSI_UPMCAutoAssigning]
	-- Add the parameters
	@IDWorkOrder int
AS
BEGIN
	SET NOCOUNT ON;

	-- Declare Constants 
	DECLARE @COMPLETE_STATUS int = 28;

	--Declare WO Variables			
	DECLARE @WOStatus VARCHAR(10);
	DECLARE @SegmentID INT;
	DECLARE @WONumber INT;
	DECLARE @Offset INT;

	-- Initialize WO variables
	SELECT	@WOStatus=STAT.Code,						
			@SegmentID=WO.IDSegment,
			@WONumber=WO.WONumber,
			@Offset=TZ.Offset
	FROM tblWorkOrders WO
	JOIN tblStatusCodes STAT
		ON WO.IDStatus = STAT.IDStatus
	JOIN tblSubStatusCodes SUBSTAT
		ON WO.IDSubStatus = SUBSTAT.IDSubStatus
	JOIN tblTypeCodes WOTYPE
		ON WO.IDType = WOTYPE.IDType
	JOIN tblSegments SEG
		ON WO.IDSegment = SEG.IDSegment
	JOIN tblTimeZones TZ 
		ON SEG.IDTimeZone = TZ.IDTimeZone
	WHERE IDWorkOrder = @IDWorkOrder

	-- Ensure WO exists and its status is complete 
	IF @WONumber IS NOT NULL AND @WOStatus = 'CMPLT' 
	BEGIN
		-- Grab start date of most recent time charge associated with the WO
		DECLARE @WorkCompleteDate DATETIME = (SELECT MAX(StartDate) FROM tblTimeCharges WHERE IDWorkOrder = @IDWorkOrder)

		-- If a time charge exists, try to update 
		IF @WorkCompleteDate IS NOT NULL 
		BEGIN
			-- Update WorkCompleteDate in utblWO record if it already exists 
			-- Otherwise, create the utblWO record
			IF EXISTS(SELECT IDWorkOrder2 FROM utblWorkOrders WHERE IDWorkOrder2 = @IDWorkOrder)
			BEGIN
				UPDATE utblWorkOrders
					SET WorkCompleteDate = DATEADD(MINUTE, @Offset, @WorkCompleteDate) -- Add timezone offset so the GUI displays the correct date
				WHERE IDWorkOrder2 = @IDWorkOrder
			END
			ELSE
			BEGIN
				INSERT INTO utblWorkOrders (IDWorkOrder2, DateCreated, DateUpdated, WorkCompleteDate)
					VALUES(@IDWorkOrder, GETDATE(), GETDATE(), DATEADD(MINUTE, @Offset, @WorkCompleteDate))
			END
		END
		ELSE
		BEGIN
			-- Deletes the work complete date in case the Time charges were removed 
			IF EXISTS(SELECT IDWorkOrder2 FROM utblWorkOrders WHERE IDWorkOrder2 = @IDWorkOrder)
			BEGIN
				UPDATE utblWorkOrders
					SET WorkCompleteDate = NULL
				WHERE IDWorkOrder2 = @IDWorkOrder
			END
		END
	END
END