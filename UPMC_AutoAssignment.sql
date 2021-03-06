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
ALTER PROCEDURE [dbo].[spSI_UPMCAutoAssigning]
	-- Add the parameters
	@IDWorkOrder int
AS
BEGIN
	SET NOCOUNT ON;

	-- Declare Constants 
	DECLARE @COMPLETE_STATUS INT = 28, @AUTOASSIGN_STATUS INT = 362, @AUTOASSIGN_SUBSTATUS INT = 250, @SCHEDULING_TYPE INT = 703;

	--Declare WO Variables			
	DECLARE @WOStatus INT,
		    @Segment INT,
			@WONumber INT,
			@Offset INT,
			@Status INT,
			@WOSubStatus INT,
			@Skill INT,
			@WOType INT;

	-- Initialize WO variables
	SELECT	@WOStatus=WO.IDStatus,
		    @WOSubstatus=WO.IDSubStatus,
			@Skill = WO.IDSkill,					
			@Segment=WO.IDSegment,
			@WONumber=WO.WONumber,
			@Offset=TZ.Offset,
			@WOType=WO.IDType
	FROM tblWorkOrders WO
		JOIN tblStatusCodes STAT ON WO.IDStatus = STAT.IDStatus
		JOIN tblSubStatusCodes SUBSTAT ON WO.IDSubStatus = SUBSTAT.IDSubStatus
		JOIN tblTypeCodes WOTYPE ON WO.IDType = WOTYPE.IDType
		JOIN tblSegments SEG ON WO.IDSegment = SEG.IDSegment
		JOIN tblTimeZones TZ ON SEG.IDTimeZone = TZ.IDTimeZone
	WHERE IDWorkOrder = @IDWorkOrder

	-- Ensure WO exists and it's status is Save & Auto-assign 
	IF @WONumber IS NOT NULL AND @WOStatus = @AUTOASSIGN_STATUS
	BEGIN
		DECLARE @Now DATETIME = GETDATE();
		DECLARE @ValidScheduleCount INT;
		-- Parse Date and Time from timestamp
		DECLARE @CurrentDate DATE = @Now, @CurrentTime TIME = @Now;

		-- Create Temp Table of all viable schedules that are currently active
		SELECT *
		INTO #tmpValidSchedules
		FROM (
				   SELECT IDWorkOrder AS IDWorkOrder, 
				   Description,
				   DATEADD(MINUTE, -@Offset, CUSTOMFIELDS.ScheduleStart) AS ScheduleStart,
				   DATEADD(MINUTE, -@Offset, CUSTOMFIELDS.ScheduleEnd) AS ScheduleEnd,
				   DATEADD(MINUTE, -@Offset, CONVERT(TIME, CUSTOMFIELDS.ShiftStart)) AS ShiftStart,
				   DATEADD(MINUTE, -@Offset, CONVERT(TIME, CUSTOMFIELDS.ShiftEnd)) AS ShiftEnd
			FROM tblWorkOrders WO
				LEFT JOIN utblWorkOrders CUSTOMFIELDS ON WO.IDWorkOrder = CUSTOMFIELDS.IDWorkOrder2
			WHERE IDType = @SCHEDULING_TYPE
				 AND IDSkill = @Skill
				 AND @CurrentDate BETWEEN DATEADD(MINUTE, -@Offset, CUSTOMFIELDS.ScheduleStart) AND DATEADD(MINUTE, -@Offset, CUSTOMFIELDS.ScheduleEnd) 
				 AND @CurrentTime BETWEEN DATEADD(MINUTE, -@Offset, CAST(CUSTOMFIELDS.ShiftStart AS TIME)) AND DATEADD(MINUTE, -@Offset, CAST(CUSTOMFIELDS.ShiftEnd AS TIME)) 
			) AS tmp

		SET @ValidScheduleCount = (SELECT COUNT(*) FROM #tmpValidSchedules);
		print 'valid schedules...' + CAST(@ValidScheduleCount AS VARCHAR(MAX));
		-- Make sure we have a schedule to work with
		IF @ValidScheduleCount > 0
		BEGIN
			-- Declare Schedule Variables 
			DECLARE @ScheduleStart DATE, @ScheduleEnd DATE, @ShiftStart TIME, @ShiftEnd TIME, @ScheduleID INT;
			
			-- Initialize schedule variables from chosen schedule 
			SELECT @ScheduleID=ChosenSchedule.IDWorkOrder,
				   @ScheduleStart=ChosenSchedule.ScheduleStart,
				   @ScheduleEnd=ChosenSchedule.ScheduleEnd,
				   @ShiftStart=ChosenSchedule.ShiftStart,
				   @ShiftEnd=ChosenSchedule.ShiftEnd
			FROM (  -- This is how we choose the schedule if more than 1 is returned 
					SELECT TOP 1 * FROM #tmpValidSchedules 
					WHERE ShiftEnd = (SELECT MAX(ShiftEnd) FROM #tmpValidSchedules)
				 ) AS ChosenSchedule
			
			-- Validate schedule data. Continue if everything looks right 
			IF @ScheduleID IS NOT NULL 
			   AND @ScheduleStart IS NOT NULL
			   AND @ScheduleEnd IS NOT NULL
			   AND @ShiftStart IS NOT NULL
			   AND @ShiftEnd IS NOT NULL
			BEGIN
				DECLARE @IDResource INT;
				DECLARE Assignments CURSOR FOR SELECT IDResource FROM tblWOAssignments WHERE IDWorkOrder = @ScheduleID

				OPEN Assignments;
				FETCH NEXT FROM Assignments INTO @IDResource;
				WHILE @@FETCH_STATUS = 0
				BEGIN

					-- Make new assignments here if they don't already exist. 
					IF NOT EXISTS(
						SELECT IDWOAssignment FROM tblWOAssignments
						WHERE IDWorkOrder = @IDWorkOrder AND IDResource = @IDResource
					)
					BEGIN
						print @IDResource
					END


					FETCH NEXT FROM Assignments INTO @IDResource;
				END
				CLOSE Assignments;
				DEALLOCATE Assignments;
			END
			
		END 
		-- Clean up
		DROP TABLE #tmpValidSchedules
	END
END