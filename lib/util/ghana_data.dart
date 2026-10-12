const hospitalTypes = [
  'Teaching Hospital',
  'Regional Hospital',
  'District Hospital',
  'Polyclinic',
  'Health Centre',
  'Clinic',
  'Specialist Hospital',
  'CHPS Compound',
];

const ghanaRegions = [
  'Greater Accra',
  'Ashanti',
  'Western',
  'Western North',
  'Central',
  'Eastern',
  'Volta',
  'Oti',
  'Northern',
  'North East',
  'Savannah',
  'Upper East',
  'Upper West',
  'Bono',
  'Bono East',
  'Ahafo',
];

class DepartmentTemplate {
  final String name;
  final String description;
  const DepartmentTemplate(this.name, this.description);
}

const departmentTemplates = [
  DepartmentTemplate('Accident & Emergency', '24/7 emergency care and trauma response'),
  DepartmentTemplate('Medicine & Therapeutics', 'General internal medicine and adult inpatient care'),
  DepartmentTemplate('Surgery', 'General and specialised surgical services'),
  DepartmentTemplate('Obstetrics & Gynaecology', 'Women’s health, antenatal, and gynaecological care'),
  DepartmentTemplate('Maternity', 'Labour, delivery, and postnatal ward'),
  DepartmentTemplate('Child Health', 'Paediatrics and neonatal care'),
  DepartmentTemplate('Intensive Care Unit', 'Critical and high-dependency care'),
  DepartmentTemplate('Outpatient Department', 'Walk-in consultations and follow-up clinics'),
  DepartmentTemplate('Pharmacy', 'Dispensing, drug management, and clinical pharmacy'),
  DepartmentTemplate('Radiology', 'X-ray, ultrasound, CT, and imaging services'),
  DepartmentTemplate('Pathology & Laboratory', 'Diagnostic lab and pathology services'),
  DepartmentTemplate('Anaesthesia', 'Theatre and pain management support'),
  DepartmentTemplate('Cardiology', 'Heart and cardiovascular care'),
  DepartmentTemplate('Orthopaedics', 'Bone, joint, and trauma orthopaedic care'),
  DepartmentTemplate('Eye Clinic', 'Ophthalmology and optometry services'),
  DepartmentTemplate('ENT', 'Ear, nose, and throat care'),
  DepartmentTemplate('Psychiatry', 'Mental health assessment and treatment'),
  DepartmentTemplate('Physiotherapy', 'Rehabilitation and physical therapy'),
  DepartmentTemplate('Dental', 'Dental and oral health services'),
  DepartmentTemplate('Polyclinic', 'Family medicine and general practice'),
];

const wardPresets = [
  'Male Medical Ward',
  'Female Medical Ward',
  'Male Surgical Ward',
  'Female Surgical Ward',
  'Paediatric Ward',
  'Maternity Ward',
  'Delivery Suite',
  'Labour Ward',
  'Gynaecology Ward',
  'Orthopaedic Ward',
  'ICU',
  'NICU',
  'PICU',
  'HDU',
  'A&E',
  'OPD',
  'Theatre',
  'Recovery Ward',
  'Isolation Ward',
  'Psychiatric Ward',
  'Eye Ward',
  'ENT Ward',
  'Burns Ward',
];

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
