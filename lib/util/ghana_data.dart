const staffCategories = [
  'Nurse',
  'Midwife',
  'Nurse Assistant',
  'Community Health Nurse',
  'Mental Health Nurse',
  'Doctor',
  'Physician Assistant',
  'Pharmacist',
  'Lab Technician',
  'Biomedical Scientist',
  'Radiographer',
  'Physiotherapist',
  'Anaesthetist',
  'Dietitian',
  'Health Records Officer',
  'Other',
];

const nurseRanks = [
  'Staff Nurse',
  'Senior Staff Nurse',
  'Nursing Officer',
  'Senior Nursing Officer',
  'Principal Nursing Officer',
  'Deputy Chief Nursing Officer',
  'Deputy Director of Nursing Services',
  'Director of Nursing Services',
  'Regional Chief Nursing & Midwifery Officer',
  'Director, Nursing & Midwifery Service',
];

const midwifeRanks = [
  'Midwifery Aid',
  'Registered Midwife',
  'Staff Midwife',
  'Senior Staff Midwife',
  'Midwifery Officer',
  'Senior Midwifery Officer',
  'Principal Midwifery Officer',
  'Assistant Midwifery Principal',
  'Deputy Chief Midwifery Officer',
];

const nurseAssistantRanks = [
  'Nurse Assistant Clinical',
  'Nurse Assistant Preventive',
  'Enrolled Nurse',
  'Senior Enrolled Nurse',
  'Principal Enrolled Nurse',
];

const communityHealthRanks = [
  'Community Health Nurse',
  'Senior Community Health Nurse',
  'Community Health Nursing Officer',
  'Senior Community Health Nursing Officer',
  'Principal Community Health Nursing Officer',
];

const medicalRanks = [
  'House Officer',
  'Medical Officer',
  'Senior Medical Officer',
  'Specialist',
  'Senior Specialist',
  'Consultant',
  'Senior Consultant',
];

const physicianAssistantRanks = [
  'Physician Assistant',
  'Senior Physician Assistant',
  'Principal Physician Assistant',
];

const pharmacistRanks = [
  'Intern Pharmacist',
  'Pharmacist',
  'Senior Pharmacist',
  'Principal Pharmacist',
  'Consultant Pharmacist',
];

const anaesthetistRanks = [
  'Anaesthetist',
  'Senior Anaesthetist',
  'Principal Anaesthetist',
  'Consultant Anaesthetist',
];

const alliedRanks = [
  'Technician',
  'Senior Technician',
  'Technical Officer',
  'Senior Technical Officer',
  'Principal Technical Officer',
  'Chief Technical Officer',
];

const ranksByCategory = <String, List<String>>{
  'Nurse': nurseRanks,
  'Midwife': midwifeRanks,
  'Nurse Assistant': nurseAssistantRanks,
  'Community Health Nurse': communityHealthRanks,
  'Mental Health Nurse': nurseRanks,
  'Doctor': medicalRanks,
  'Physician Assistant': physicianAssistantRanks,
  'Pharmacist': pharmacistRanks,
  'Lab Technician': alliedRanks,
  'Radiographer': alliedRanks,
  'Physiotherapist': alliedRanks,
  'Anaesthetist': anaesthetistRanks,
  'Dietitian': alliedRanks,
  'Biomedical Scientist': alliedRanks,
  'Health Records Officer': alliedRanks,
  'Other': alliedRanks,
};

const wardRoles = [
  (value: 'regular', label: 'Regular staff'),
  (value: 'incharge', label: 'Ward in-charge'),
  (value: 'assistant', label: 'Assistant in-charge'),
  (value: 'shift_incharge', label: 'Shift in-charge'),
  (value: 'unit_manager', label: 'Unit manager'),
  (value: 'team_leader', label: 'Team leader'),
  (value: 'preceptor', label: 'Clinical preceptor'),
  (value: 'intern', label: 'Intern / student'),
];

List<String> ranksForCategory(String category) =>
    List<String>.from(ranksByCategory[category] ?? alliedRanks);
