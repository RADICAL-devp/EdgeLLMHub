class ClinicalSamples {
  static const List<String> cardiology = [
    '''Patient is a 65M with PMH of hypertension, diabetes, and hyperlipidemia who presents with 30 minutes of crushing substernal chest pain radiating to the left arm. Pain is 8/10, associated with diaphoresis and nausea. EKG shows ST elevation in leads II, III, and aVF. Troponin is pending.''',
    '''58F with PMH of atrial fibrillation (on warfarin) presents with palpitations and lightheadedness. Vital signs: HR 160, BP 90/60, RR 20, SpO2 98% on RA. EKG shows rapid AFib with no clear P waves. INR is 1.2.''',
    '''42M with no PMH presents with sudden onset of tearing chest pain radiating to the back. Pain is 10/10, worst of his life. BP is 180/100 in the right arm, 120/80 in the left arm. Chest X-ray shows widened mediastinum.''',
    '''67F with PMH of type 2 diabetes and hypertension presents with 2 weeks of progressive shortness of breath on exertion and bilateral lower extremity edema. EF is 35% on echocardiogram. Troponin negative.''',
    '''55M with PMH of smoking and hyperlipidemia presents with intermittent substernal chest pressure lasting 5-10 minutes, triggered by exertion, relieved by rest. EKG shows normal sinus rhythm.''',
    '''72M with PMH of prior MI (stent placed 2 years ago) presents with recurrent chest pain at rest. EKG shows ST depression in leads V4-V6. High-sensitivity troponin is elevated.''',
    '''61F presents with palpitations and anxiety for 1 week. No chest pain. EKG shows atrial fibrillation with rapid ventricular response. Beta-blocker initiated.''',
    '''48M with PMH of congenital heart disease (tetralogy of Fallot, repaired) presents with progressive dyspnea on exertion. Oxygen saturation 92% on room air.''',
    '''78F with PMH of hypertension and CKD presents with sudden onset of severe dyspnea and orthopnea. BNP elevated. Chest X-ray shows pulmonary edema.''',
    '''53M presents with syncope during exercise. EKG shows left bundle branch block. Exercise stress test terminated due to ST depression.''',
    '''64F with PMH of diabetes and smoking presents with 3 days of worsening shortness of breath and productive cough with green sputum. Crackles bilateral bases.''',
    '''39M with no PMH presents with sharp, pleuritic chest pain for 2 days. Worse with inspiration. EKG normal. D-dimer elevated.''',
    '''70M with PMH of coronary artery disease (CAD) presents with stable angina progressing to unstable pattern. Crossover to ccc blocker initiated.''',
    '''56F presents with episodic palpitations, sweating, and anxiety. Thyroid function tests show supraventricular tachycardia. Radioactive iodine uptake scan ordered.''',
    '''69M with PMH of heart failure with reduced ejection fraction presents with 3-day history of weight gain and increasing edema. Diuretic adjustment needed.''',
  ];

  static const List<String> neurology = [
    '''72M with PMH of hypertension and diabetes presents with sudden onset of right-sided weakness and slurred speech 2 hours ago. On exam, he has 2/5 strength in right arm and leg, right facial droop, and dysarthria. NIH Stroke Scale is 8.''',
    '''34F with no PMH presents with 1 hour of severe, sudden-onset "thunderclap" headache, described as the worst headache of her life. No focal neuro deficits. CT head is normal.''',
    '''28M with PMH of epilepsy presents with a witnessed generalized tonic-clonic seizure lasting 2 minutes. Post-ictal, he is confused but otherwise at baseline. No tongue biting or incontinence.''',
    '''65F with PMH of atrial fibrillation presents with sudden onset of left-sided numbness and weakness. MRI shows acute infarct in right MCA territory. Onset to door time was 45 minutes.''',
    '''45M presents with 3 months of progressive difficulty with word finding and repeated episodes of confusion. Mini-mental state exam score is 24/30. MRI shows frontal atrophy.''',
    '''52F with PMH of migraine with aura presents with new-onset focal neurological deficits lasting 1 hour. CT head negative for hemorrhage.''',
    '''38M presents with 2 weeks of progressive gait instability and dizziness. MRI shows cerebellar mass with surrounding edema. Neurosurgery consult pending.''',
    '''74M with PMH of Parkinson's disease presents with 6-month history of worsening tremor and rigidity despite medication adjustments. Off-period dystonia.''',
    '''22F presents with recurrent headaches with photophobia and phonophobia lasting 4-72 hours. No aura. Preventive therapy considered.''',
    '''61M presents with 1 week of double vision and difficulty swallowing. MRI shows brainstem lesion. Suspected multiple sclerosis.''',
    '''57F presents with 3 days of progressive weakness in both legs and urinary retention. MRI shows thoracic spinal cord lesion. Suspected transverse myelitis.''',
    '''43M with PMH of HIV presents with 2 weeks of headache and confusion. MRI shows ring-enhancing lesions. Toxoplasmosis suspected.''',
    '''68F presents with 6-month history of cognitive decline, hallucinations, and parkinsonism. MRI shows diffuse cortical atrophy. Suspected Lewy body dementia.''',
    '''31M presents with 3 days of severe headache, fever, and neck stiffness. Lumbar puncture shows elevated white cells. Suspected meningitis.''',
    '''55M with PMH of hypertension presents with sudden onset of right-sided facial droop and slurred speech, resolving within 1 hour. TIA suspected. ABCD2 score calculated.''',
  ];

  static const List<String> pediatrics = [
    '''2-year-old male presents with 3 days of fever to 102°F, rhinorrhea, and cough. Today, he developed a rash on his trunk and face. Immunizations are up to date. Exam shows erythematous maculopapular rash, clear lungs, and no focal findings.''',
    '''Newborn male, born at 38 weeks via NSVD, now 4 days old, presents with poor feeding, lethargy, and temperature of 96.8°F. Birth history is unremarkable. Exam shows a listless infant with mottled skin and weak cry.''',
    '''5-year-old female presents with 2 weeks of persistent fever, joint pain, and rash. ESR elevated. Suspected juvenile idiopathic arthritis. ANA positive.''',
    '''8-year-old male presents with headache, vomiting, and visual changes for 1 week. MRI shows cerebellar pilocytic astrocytoma. Neurosurgery consult.''',
    '''3-year-old female presents with 3-day history of high fever and sore throat. Exam shows strawberry tongue and cervical lymphadenopathy. Scarlet fever suspected.''',
    '''12-year-old male presents with intermittent limp and hip pain for 2 weeks. X-ray shows slipped capital femoral epiphysis. Orthopedic referral.''',
    '''6-month-old female presents with 2-day history of forceful projectile vomiting after feeds. Exam shows olive-shaped mass in epigastrium. Pyloric stenosis suspected.''',
    '''4-year-old male presents with recurrent episodes of wheezing and cough, especially at night and with exercise. Asthma suspected. Spirometry pending.''',
    '''9-year-old female presents with 2-week history of daily headaches, worse in the morning. Fundoscopy shows papilledema. MRI ordered.''',
    '''15-month-old male presents with 3-day history of diarrhea and vomiting, decreased urine output. Signs of dehydration. Oral rehydration initiated.''',
    '''7-year-old female presents with fatigue, pallor, and petechiae for 1 week. CBC shows anemia and thrombocytopenia. Bone marrow biopsy ordered.''',
    '''10-year-old male presents with 2-day history of testicular pain and swelling. Exam shows tender, enlarged left testicle. Ultrasound shows torsion. Emergency surgery.''',
    '''18-month-old female presents with developmental regression, loss of speech, and hand-wringing movements. Rett syndrome suspected. Genetic testing ordered.''',
    '''5-year-old male presents with 3-day history of fever, rash, and conjunctivitis. Desquamation of hands and feet noted. Kawasaki disease suspected.''',
    '''11-year-old female presents with 4-week history of progressive difficulty walking and behavioral changes. MRI shows cerebellar demyelination. Acute disseminated encephalomyelitis suspected.''',
  ];

  static const List<String> general = [
    '''45M with no PMH presents with 1 week of productive cough, fever, and dyspnea. Chest X-ray shows right lower lobe consolidation. Vital signs: T 101.5°F, HR 105, RR 22, SpO2 92% on RA.''',
    '''68F with PMH of COPD (FEV1 40% predicted) presents with increased shortness of breath and purulent sputum for 3 days. She is on home O2 at 2L/min. Vital signs: T 99.8°F, HR 110, RR 28, SpO2 88% on 2L NC.''',
    '''34F presents with 2 weeks of fatigue, weight gain, and cold intolerance. TSH elevated, free T4 low. Hypothyroidism confirmed.''',
    '''56M with PMH of type 2 diabetes presents with 3-day history of polyuria, polydipsia, and blurry vision. Glucose 380 mg/dL, HbA1c 9.2%. Insulin adjustment needed.''',
    '''41F presents with 6-month history of intermittent abdominal pain, bloating, and altered bowel habits. IBS suspected. Colonoscopy normal.''',
    '''73M with PMH of hypertension and hyperlipidemia presents with 2-day history of confusion and forgetfulness. CT head shows lacunar infarcts. No hemorrhagic change.''',
    '''29F presents with 1 week of bilateral joint pain, morning stiffness, and symmetric hand swelling. Rheumatoid factor positive. Rheumatoid arthritis suspected.''',
    '''62M with PMH of GERD presents with 3-week history of progressive dysphagia to solids. Weight loss of 10 pounds. Endoscopy shows esophageal stricture.''',
    '''47F presents with 2-day history of severe right flank pain radiating to groin. CT shows 8mm renal stone. Hydration and pain management initiated.''',
    '''51M with PMH of obesity (BMI 36) presents with 6-month history of excessive daytime sleepiness and loud snoring. Sleep study shows OSA. CPAP recommended.''',
    '''38F presents with 3-day history of diffuse abdominal pain, nausea, and vomiting. CT abdomen shows acute pancreatitis. Lipase elevated.''',
    '''77F with PMH of dementia presents with 2-day history of decreased appetite and lethargy. Urinalysis shows UTI. Antibiotics initiated.''',
    '''54M with PMH of HIV presents with 1-month history of progressive weight loss and night sweats. CD4 count 180. Opportunistic infection workup ordered.''',
    '''63F presents with 3-month history of intermittent chest tightness and anxiety. Stress test negative. GERD considered. PPI trial started.''',
    '''44M with no PMH presents with 1-week history of progressive weakness in both legs and urinary retention. MRI shows cauda equina compression. Emergency neurosurgery.''',
  ];

  static List<String> get allSamples => [...cardiology, ...neurology, ...pediatrics, ...general];

  static void assertMinSamples(int count) {
    assert(allSamples.length >= count, 'Need at least $count clinical samples (current: ${allSamples.length})');
  }
}
