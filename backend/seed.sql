-- PharmaSaathi AI — seed data
-- Run AFTER schema.sql. Loads the same medicine catalog and interaction
-- rules already used in the frontend prototype, so the backend starts
-- with real, demo-ready content instead of an empty database.

insert into medicine_catalog (id, icon, name_en, name_hi, use_en, use_hi, dose_line_en, dose_line_hi,
  adult_dose_en, adult_dose_hi, child_dose_en, child_dose_hi, liquid_en, liquid_hi,
  moa_en, moa_hi, antidote_en, antidote_hi, contraindications_en, contraindications_hi,
  interaction_text_en, interaction_text_hi)
values
('metformin','💊','Metformin 500mg','Metformin 500mg','Type 2 diabetes','टाइप 2 डायबिटीज़',
 '1 tablet · twice daily · after food','1 टैबलेट · दिन में दो बार · भोजन के बाद',
 '1 tablet (500mg), twice daily, with food','1 टैबलेट (500mg), दिन में दो बार, भोजन के साथ',
 'Not usually prescribed under 10 yrs. Ages 10–16 (extended-release only): specialist-guided, mg/kg basis.',
 'आमतौर पर 10 वर्ष से कम उम्र में नहीं दी जाती। 10–16 वर्ष (केवल एक्सटेंडेड-रिलीज़): विशेषज्ञ की सलाह अनुसार, वज़न (mg/kg) के आधार पर।',
 'No standard liquid formulation.','कोई मानक तरल (सिरप) रूप उपलब्ध नहीं है।',
 'Lowers glucose production by the liver and improves how muscle tissue responds to insulin.',
 'लिवर द्वारा ग्लूकोज़ उत्पादन को कम करता है और मांसपेशियों की इंसुलिन के प्रति प्रतिक्रिया को बेहतर बनाता है।',
 'No specific antidote. Overdose risk is lactic acidosis — treated with IV sodium bicarbonate and, in severe cases, hemodialysis.',
 'कोई विशेष प्रतिविष (एंटीडोट) नहीं है। अधिक मात्रा से लैक्टिक एसिडोसिस का खतरा — IV सोडियम बाइकार्बोनेट से उपचार, गंभीर मामलों में हीमोडायलिसिस।',
 '["Severe kidney impairment (eGFR below 30)","Metabolic acidosis","Acute or unstable heart failure"]',
 '["गंभीर किडनी रोग (eGFR 30 से कम)","मेटाबॉलिक एसिडोसिस","तीव्र या अस्थिर हृदय विफलता (हार्ट फेलियर)"]',
 'Space at least 2 hours from calcium or iron supplements. Avoid alcohol — raises lactic-acidosis risk.',
 'कैल्शियम या आयरन सप्लीमेंट से कम से कम 2 घंटे का अंतर रखें। शराब से बचें — लैक्टिक एसिडोसिस का खतरा बढ़ता है।'),

('amoxicillin','💊','Amoxicillin 500mg','Amoxicillin 500mg','Bacterial infection','बैक्टीरियल संक्रमण',
 '1 capsule · 3× daily · 8 hrs apart','1 कैप्सूल · दिन में 3 बार · 8 घंटे के अंतर पर',
 '1 capsule (500mg) every 8 hours, complete the full course','1 कैप्सूल (500mg) हर 8 घंटे में, पूरा कोर्स ज़रूर लें',
 '25–45 mg/kg/day, split into 2–3 doses. Confirm exact dose with pediatrician.',
 '25–45 mg/kg/दिन, 2–3 खुराकों में बाँटकर। सटीक खुराक बाल रोग विशेषज्ञ से पुष्टि करें।',
 'Liquid syrup 125mg/5ml — e.g. a 15kg child ≈ 5ml, three times daily (example only).',
 'तरल सिरप 125mg/5ml — उदाहरण: 15kg के बच्चे को ≈ 5ml, दिन में तीन बार (केवल उदाहरण)।',
 'Breaks down the bacterial cell wall, causing susceptible bacteria to rupture and die.',
 'बैक्टीरिया की कोशिका भित्ति को तोड़ता है, जिससे संवेदनशील बैक्टीरिया फटकर नष्ट हो जाते हैं।',
 'No antidote required for normal use. For a severe allergic reaction (anaphylaxis): antihistamines and epinephrine.',
 'सामान्य उपयोग में किसी प्रतिविष की आवश्यकता नहीं। गंभीर एलर्जी प्रतिक्रिया (एनाफिलैक्सिस) में: एंटीहिस्टामिन और एपिनेफ्रिन।',
 '["Known penicillin allergy","Caution in infectious mononucleosis (rash risk)"]',
 '["पेनिसिलिन से ज्ञात एलर्जी","इन्फेक्शियस मोनोन्यूक्लिओसिस में सावधानी (रैश का खतरा)"]',
 null, null),

('levothyroxine','💊','Levothyroxine 50mcg','Levothyroxine 50mcg','Hypothyroidism','हाइपोथायरॉइडिज़्म',
 '1 tablet · once daily · empty stomach','1 टैबलेट · दिन में एक बार · खाली पेट',
 '1 tablet (50mcg), once daily, 30–60 min before breakfast','1 टैबलेट (50mcg), दिन में एक बार, नाश्ते से 30–60 मिनट पहले',
 'Weight-based (mcg/kg/day) — set by pediatric endocrinologist.','वज़न अनुसार (mcg/kg/दिन) — बाल एंडोक्राइनोलॉजिस्ट द्वारा तय की जाती है।',
 'Tablet can be crushed into a small amount of water for infants; do not mix with soy or iron.',
 'शिशुओं के लिए टैबलेट को थोड़े पानी में घोला जा सकता है; सोया या आयरन के साथ न मिलाएँ।',
 'Synthetic thyroid hormone (T4) that replaces what the thyroid gland is not producing enough of.',
 'कृत्रिम थायरॉइड हार्मोन (T4) जो थायरॉइड ग्रंथि की कमी को पूरा करता है।',
 'No specific antidote for overdose. Beta-blockers are used to manage cardiac symptoms in acute toxicity.',
 'अधिक मात्रा के लिए कोई विशेष प्रतिविष नहीं। तीव्र विषाक्तता में हृदय संबंधी लक्षणों के लिए बीटा-ब्लॉकर का उपयोग किया जाता है।',
 '["Untreated adrenal insufficiency","Recent acute heart attack","Uncontrolled hyperthyroidism"]',
 '["अनुपचारित एड्रिनल अपर्याप्तता","हाल ही में हुआ हृदयाघात (हार्ट अटैक)","अनियंत्रित हाइपरथायरॉइडिज़्म"]',
 'Leave at least 4 hours between Levothyroxine and Calcium or Iron supplements — they bind to it and block absorption.',
 'Levothyroxine और कैल्शियम या आयरन सप्लीमेंट के बीच कम से कम 4 घंटे का अंतर रखें — ये इससे जुड़कर अवशोषण रोकते हैं।'),

('paracetamol','💊','Paracetamol 650mg','Paracetamol 650mg','Fever / pain relief','बुखार / दर्द निवारण',
 '1 tablet · every 6 hrs · max 4/day','1 टैबलेट · हर 6 घंटे में · अधिकतम 4/दिन',
 '1 tablet (650mg) every 6 hours, maximum 4 doses (4g) in 24 hours','1 टैबलेट (650mg) हर 6 घंटे में, 24 घंटे में अधिकतम 4 खुराक (4g)',
 '10–15 mg/kg every 4–6 hours, maximum 4 doses/day.','10–15 mg/kg हर 4–6 घंटे में, अधिकतम 4 खुराक/दिन।',
 'Liquid syrup 250mg/5ml — e.g. a 12kg child ≈ 3ml (example only, confirm with pharmacist).',
 'तरल सिरप 250mg/5ml — उदाहरण: 12kg के बच्चे को ≈ 3ml (केवल उदाहरण, फार्मासिस्ट से पुष्टि करें)।',
 'Blocks prostaglandin production in the brain, reducing fever and the perception of pain.',
 'मस्तिष्क में प्रोस्टाग्लैंडिन के उत्पादन को रोकता है, जिससे बुखार और दर्द की अनुभूति कम होती है।',
 'N-acetylcysteine (NAC) — the drug of choice for overdose, most effective within 8–10 hours of ingestion.',
 'N-acetylcysteine (NAC) — अधिक मात्रा के लिए प्राथमिक उपचार दवा, सेवन के 8–10 घंटे के भीतर सबसे प्रभावी।',
 '["Severe liver impairment","Chronic heavy alcohol use"]','["गंभीर लिवर रोग","लंबे समय से अत्यधिक शराब का सेवन"]',
 'Avoid combining with any other paracetamol-containing product — a common cause of accidental overdose.',
 'किसी अन्य पैरासिटामोल-युक्त दवा के साथ न लें — यह गलती से अधिक मात्रा लेने का सामान्य कारण है।'),

('ibuprofen','💊','Ibuprofen 400mg','Ibuprofen 400mg','Pain / inflammation relief','दर्द / सूजन से राहत',
 '1 tablet · up to 3× daily · with food','1 टैबलेट · अधिकतम दिन में 3 बार · भोजन के साथ',
 '1 tablet (400mg) every 6–8 hours as needed, maximum 3 doses/day, with food',
 '1 टैबलेट (400mg) हर 6–8 घंटे में आवश्यकतानुसार, अधिकतम 3 खुराक/दिन, भोजन के साथ',
 '5–10 mg/kg every 6–8 hours (age 3 months+). Confirm with pediatrician.',
 '5–10 mg/kg हर 6–8 घंटे में (3 महीने+ आयु)। बाल रोग विशेषज्ञ से पुष्टि करें।',
 'Liquid suspension 100mg/5ml available — dose by weight, confirm with pharmacist.',
 'तरल सिरप 100mg/5ml उपलब्ध — वज़न अनुसार खुराक, फार्मासिस्ट से पुष्टि करें।',
 'Blocks COX enzymes to reduce prostaglandin production, easing pain, swelling and fever.',
 'COX एंज़ाइम को रोककर प्रोस्टाग्लैंडिन उत्पादन घटाता है, जिससे दर्द, सूजन और बुखार कम होता है।',
 'No specific antidote. Overdose managed with supportive care and activated charcoal if early.',
 'कोई विशेष प्रतिविष नहीं। अधिक मात्रा में सहायक उपचार व शुरुआत में एक्टिवेटेड चारकोल दिया जाता है।',
 '["Active stomach ulcer or GI bleeding","Severe kidney or heart failure","Known NSAID/aspirin allergy"]',
 '["सक्रिय पेट का अल्सर या GI ब्लीडिंग","गंभीर किडनी या हृदय विफलता","NSAID/एस्पिरिन से ज्ञात एलर्जी"]',
 null, null),

('omeprazole','💊','Omeprazole 20mg','Omeprazole 20mg','Acid reflux / stomach protection','एसिड रिफ्लक्स / पेट की सुरक्षा',
 '1 capsule · once daily · before breakfast','1 कैप्सूल · दिन में एक बार · नाश्ते से पहले',
 '1 capsule (20mg) once daily, 30–60 min before breakfast','1 कैप्सूल (20mg) दिन में एक बार, नाश्ते से 30–60 मिनट पहले',
 'Weight-based, specialist-guided for children under 12.','वज़न अनुसार, 12 वर्ष से कम आयु में विशेषज्ञ की सलाह अनुसार।',
 'Capsule can be opened and mixed with soft food for those with swallowing difficulty (non-enteric use only).',
 'निगलने में कठिनाई होने पर कैप्सूल खोलकर नरम भोजन में मिलाया जा सकता है (केवल non-enteric उपयोग)।',
 'Reduces stomach acid production by blocking the proton pump in the stomach lining.',
 'पेट की परत में प्रोटॉन पंप को रोककर एसिड उत्पादन घटाता है।',
 'No specific antidote required for standard overdose; supportive care only.',
 'सामान्य अधिक मात्रा के लिए कोई विशेष प्रतिविष आवश्यक नहीं; केवल सहायक उपचार।',
 '["Known hypersensitivity to PPIs","Long-term use without periodic review (bone fracture, B12 risk)"]',
 '["PPI से ज्ञात अतिसंवेदनशीलता","बिना समीक्षा दीर्घकालिक उपयोग (हड्डी फ्रैक्चर, B12 का खतरा)"]',
 null, null),

('azithromycin','💊','Azithromycin 250mg','Azithromycin 250mg','Bacterial infection (5-day course)','बैक्टीरियल संक्रमण (5-दिन का कोर्स)',
 '1 tablet · once daily · 5-day course','1 टैबलेट · दिन में एक बार · 5-दिन का कोर्स',
 '1 tablet (250mg) once daily for 5 days, or as prescribed','1 टैबलेट (250mg) दिन में एक बार, 5 दिनों तक, या डॉक्टर की सलाह अनुसार',
 '10 mg/kg once daily for 3 days, or per the pediatrician''s course.',
 '10 mg/kg दिन में एक बार, 3 दिनों तक, या बाल रोग विशेषज्ञ के कोर्स अनुसार।',
 'Liquid suspension 200mg/5ml available — dose by weight, confirm with pharmacist.',
 'तरल सिरप 200mg/5ml उपलब्ध — वज़न अनुसार खुराक, फार्मासिस्ट से पुष्टि करें।',
 'Stops bacteria from making the proteins they need to grow, halting the infection.',
 'बैक्टीरिया को बढ़ने के लिए आवश्यक प्रोटीन बनाने से रोकता है, जिससे संक्रमण रुक जाता है।',
 'No specific antidote. Overdose managed with supportive care.','कोई विशेष प्रतिविष नहीं। अधिक मात्रा में सहायक उपचार दिया जाता है।',
 '["Known macrolide allergy","Caution with existing heart rhythm problems (QT prolongation)"]',
 '["मैक्रोलाइड से ज्ञात एलर्जी","मौजूदा हृदय-लय समस्याओं में सावधानी (QT प्रोलोंगेशन)"]',
 null, null),

('cetirizine','💊','Cetirizine 10mg','Cetirizine 10mg','Allergy relief','एलर्जी से राहत',
 '1 tablet · once daily · anytime','1 टैबलेट · दिन में एक बार · कभी भी',
 '1 tablet (10mg) once daily','1 टैबलेट (10mg) दिन में एक बार',
 '2.5–5mg once daily (age 6–12). Confirm with pediatrician.','2.5–5mg दिन में एक बार (6–12 वर्ष)। बाल रोग विशेषज्ञ से पुष्टि करें।',
 'Syrup 5mg/5ml available for children.','बच्चों के लिए सिरप 5mg/5ml उपलब्ध।',
 'Blocks histamine receptors, reducing allergic symptoms like itching, sneezing and rash.',
 'हिस्टामिन रिसेप्टर्स को रोककर खुजली, छींक और रैश जैसे एलर्जी लक्षण कम करता है।',
 'No specific antidote. Overdose managed with supportive care (drowsiness).',
 'कोई विशेष प्रतिविष नहीं। अधिक मात्रा में सहायक उपचार (नींद आना)।',
 '["Severe kidney impairment (dose adjustment needed)","Known hypersensitivity to cetirizine/hydroxyzine"]',
 '["गंभीर किडनी रोग (खुराक समायोजन आवश्यक)","Cetirizine/hydroxyzine से ज्ञात अतिसंवेदनशीलता"]',
 null, null)
on conflict (id) do nothing;

insert into drug_interactions (drug_a, drug_b, severity, explanation_en, explanation_hi) values
('amoxicillin','ibuprofen','risk',
 'Possible interaction flagged between Amoxicillin and Ibuprofen in this patient''s current list — confirm timing with pharmacist before combining.',
 'इस मरीज़ की सूची में Amoxicillin और Ibuprofen के बीच संभावित इंटरैक्शन चिह्नित है — साथ लेने से पहले फार्मासिस्ट से समय की पुष्टि करें।'),
('ibuprofen','levothyroxine','warn',
 'Regular Ibuprofen use can reduce how well Levothyroxine is absorbed — keep Levothyroxine on an empty stomach, well separated from Ibuprofen doses.',
 'नियमित Ibuprofen लेने से Levothyroxine का अवशोषण घट सकता है — Levothyroxine खाली पेट व Ibuprofen की खुराक से अलग समय पर लें।'),
('levothyroxine','omeprazole','warn',
 'Omeprazole lowers stomach acid, which can reduce Levothyroxine absorption — separate the two by at least 4 hours, ideally Levothyroxine first thing in the morning.',
 'Omeprazole पेट के एसिड को कम करता है, जिससे Levothyroxine का अवशोषण घट सकता है — दोनों के बीच कम से कम 4 घंटे का अंतर रखें, Levothyroxine सुबह सबसे पहले लें।')
on conflict do nothing;

-- ============= OCR aliases (brand names / spellings printed on Indian prescriptions) =============
update medicine_catalog set aliases = array['metformin','glycomet','glucophage','carbophage'] where id = 'metformin';
update medicine_catalog set aliases = array['amoxicillin','amoxil','novamox','amoxycillin','mox'] where id = 'amoxicillin';
update medicine_catalog set aliases = array['levothyroxine','thyronorm','eltroxin','thyrox'] where id = 'levothyroxine';
update medicine_catalog set aliases = array['paracetamol','acetaminophen','crocin','dolo','calpol','paracip'] where id = 'paracetamol';
update medicine_catalog set aliases = array['ibuprofen','brufen','ibugesic'] where id = 'ibuprofen';
update medicine_catalog set aliases = array['omeprazole','omez','ocid'] where id = 'omeprazole';
update medicine_catalog set aliases = array['azithromycin','azithral','zithromax','aziwok'] where id = 'azithromycin';
update medicine_catalog set aliases = array['cetirizine','cetzine','alerid','zyrtec'] where id = 'cetirizine';
