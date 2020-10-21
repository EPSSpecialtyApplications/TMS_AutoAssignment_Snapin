select SEG.Description AS [Segment Description], 
	   WO.WONumber AS [WO Number], 
	   WO.Description AS [WO Description], 
	   SKILL.Description AS [Skill Description], 
	   DATEADD(MINUTE, -TZ.Offset, CUSTOMFIELDS.ScheduleStart) AS ScheduleStart,
	   DATEADD(MINUTE, -TZ.Offset, CUSTOMFIELDS.ScheduleEnd) AS ScheduleEnd,
	   DATEADD(MINUTE, -TZ.Offset, CUSTOMFIELDS.ShiftStart) AS ShiftStart,
	   DATEADD(MINUTE, -TZ.Offset, CUSTOMFIELDS.ShiftEnd) AS ShiftEnd,
	   CAST(GETDATE() AS time) AS Now
from tblWorkOrders WO
	JOIN tblSegments SEG ON WO.IDSegment = SEG.IDSegment
	JOIN tblSkillCodes SKILL ON WO.IDSkill = SKILL.IDSkill
	LEFT JOIN utblWorkOrders CUSTOMFIELDS ON WO.IDWorkOrder = CUSTOMFIELDS.IDWorkOrder2
	JOIN tblTimeZones TZ ON SEG.IDTimeZone = TZ.IDTimeZone
WHERE IDType = 703  AND IDSubStatus = 249 AND 
	  CAST(GETDATE() AS DATE) BETWEEN ScheduleStart AND ScheduleEnd
	  AND DATEADD(MINUTE, 175, CAST(GETDATE() AS TIME)) BETWEEN CAST(DATEADD(MINUTE, -TZ.Offset, CUSTOMFIELDS.ShiftStart) AS TIME) AND CAST(DATEADD(MINUTE, -TZ.Offset, CUSTOMFIELDS.ShiftEnd) AS TIME)

