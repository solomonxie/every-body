"""Z-Anatomy muscles, organs, vessels and nerves → Resources/Models/{muscles,organs,vessels,nerves}.usdz.

Same source and warp as the skeleton (build_models.py): each vertex follows the bones it lies closest to,
so muscles sit on the fitted bones and vessels / nerves run along them. Objects are renamed to the app's
ids (body.json) where one exists, small pieces merged per group, muscles and organs decimated, vessels and
nerves re-meshed as thin tubes. Parts Z-Anatomy marks non-commercial (kidney, inner ear) are skipped.

  Blender -b Z-Anatomy/Startup.blend -P build_internals.py        (via scripts/models/build.sh internals)
"""

import json
import math
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_models as bm  # noqa: E402

ROOT, OUT = bm.ROOT, bm.OUT
BUDGET = {"muscular": 92_000, "organs": 34_000}
BRAIN_TRIS = 12_000
TOTAL_TRIS = (190_000, 260_000)
MIN_RADIUS = {"circulatory": 0.0016, "nervous": 0.0013}  # metres, so thin branches still read on a phone
FILES = {"muscular": "muscles.usdz", "organs": "organs.usdz", "circulatory": "vessels.usdz", "nervous": "nerves.usdz"}
TUBE_CAP = {"sympathetic-trunk-l": 1500, "sympathetic-trunk-r": 1500, "cranial-nerves-l": 2500, "cranial-nerves-r": 2500,
            "dural-sinuses": 1500, "cerebral-arteries": 3500, "spinal-cord": 2000, "cardiac-veins": 1500,
            "pulmonary-arteries": 3000, "pulmonary-veins-l": 2000, "pulmonary-veins-r": 2000}
SIGMA = 0.012  # metres: how softly a vertex blends between neighbouring bones' warps

# non-commercial sources inside Z-Anatomy (Lissie Cowley's kidney, Dundee inner ear)
NC = re.compile(r"kidney|renal pelvis|intrarenal|branch of renal artery|cochlea|vestibul|semicircular|labyrinth|"
                r"tympanic|auditory tube|endolymph|perilymph|utricle|saccule|suprarenal", re.I)

MUSCLE, TENDON = "#C1443C", "#E6D3C3"
ARTERY, VEIN, NERVE = "#D23A3A", "#3A5BD9", "#E8B923"

# ------------------------------------------------------------------ Z-Anatomy name → our id
# (pattern on the name without side, id; "{s}" = -l / -r from the name). First match wins; id None drops.

MUSCLES = [
    (r"^Frontalis", "frontalis{s}"), (r"^Occipitalis", "occipitalis{s}"), (r"^Epicranial aponeurosis", "epicranial-aponeurosis"),
    (r"orbicularis oculi", "orbicularis-oculi{s}"), (r"^Orbicularis oris", "orbicularis-oris"),
    (r"^Zygomaticus", "zygomaticus{s}"),
    (r"^(Nasalis|Procerus|Corrugator|Depressor|Levator (anguli|labii|nasolabialis)|Risorius|Mentalis|Bucinator)", "facial-muscles{s}"),
    (r"^Temporalis muscle", "temporalis{s}"), (r"part of masseter", "masseter{s}"),
    (r"^Sternocleidomastoid", "sternocleidomastoid{s}"),
    (r"digastric|^Mylohyoid|^Stylohyoid|^Geniohyoid", "suprahyoid{s}"),
    (r"^(Omohyoid|Sternohyoid|Sternothyroid|Thyrohyoid)", "infrahyoid{s}"),
    (r"^Scalenus", "scalenes{s}"), (r"^Splenius", "splenius{s}"), (r"^Levator scapulae", "levator-scapulae{s}"),
    (r"part of trapezius", "trapezius{s}"), (r"^Rhomboid", "rhomboids{s}"), (r"^Serratus posterior", "serratus-posterior{s}"),
    (r"^Latissimus", "latissimus{s}"), (r"^(Iliocostalis|Longissimus|Spinalis) ", "erector-spinae{s}"),
    (r"^(Semispinalis|Multifidus)", "transversospinales{s}"),
    (r"^Clavicular head of pectoralis major", "pectoralis-clavicular{s}"),
    (r"(Sternocostal head|Abdominal part) of pectoralis major", "pectoralis{s}"), (r"^Pectoralis minor", "pectoralis-minor{s}"),
    (r"^External intercostal", "intercostals{s}"), (r"^Serratus anterior", "serratus{s}"), (r"^Diaphragm$", "diaphragm"),
    (r"^(Rectus abdominis|Pyramidalis)", "rectus-abdominis{s}"), (r"^Linea alba$", "linea-alba"),
    (r"^External abdominal oblique", "external-oblique{s}"), (r"^Internal abdominal oblique", "internal-oblique{s}"),
    (r"^Quadratus lumborum", "quadratus-lumborum{s}"),
    (r"^(Iliococcygeus|Pubo-analis|Pubococcygeus|Coccygeus|External anal sphincter)", "pelvic-floor"),
    (r"part of deltoid", "deltoid{s}"), (r"^Supraspinatus", "supraspinatus{s}"), (r"^Infraspinatus", "infraspinatus{s}"),
    (r"^Teres minor", "teres-minor{s}"), (r"^Teres major", "teres-major{s}"), (r"^Subscapularis", "subscapularis{s}"),
    (r"head of biceps brachii", "biceps{s}"), (r"^Brachialis", "brachialis{s}"), (r"^Coracobrachialis", "coracobrachialis{s}"),
    (r"head of triceps brachii", "triceps{s}"), (r"head of flexor carpi ulnaris", "flexor-carpi-ulnaris{s}"),
    (r"pronator teres|flexor digitorum superficialis|^Flexor carpi radialis|^Palmaris longus|^Flexor digitorum profundus|"
     r"^Flexor pollicis longus|^Pronator quadratus", "forearm-flexors{s}"),
    (r"^Brachioradialis", "brachioradialis{s}"),
    (r"^Extensor digitorum\.?$|^Extensor digitorum$|extensor carpi ulnaris|^Extensor carpi radialis|^Anconeus|^Extensor digiti minimi$|"
     r"^Supinator|^Abductor pollicis longus|^Extensor indicis|^Extensor pollicis", "forearm-extensors{s}"),
    (r"flexor pollicis brevis|adductor pollicis|^Abductor pollicis brevis|^Opponens pollicis", "thenar-muscles{s}"),
    (r"of hand$|^Palmar interossei|^Opponens digiti minimi muscle of hand", "hand-muscles{s}"),
    (r"^(Iliacus|Psoas major)", "iliopsoas{s}"),
    (r"^Gluteus maximus", "gluteus-maximus{s}"), (r"^Gluteus medius", "gluteus-medius{s}"), (r"^Gluteus minimus", "gluteus-minimus{s}"),
    (r"^Tensor fasciae latae", "tensor-fasciae-latae{s}"),
    (r"^(Piriformis muscle|Quadratus femoris|Inferior gemellus|Superior gemellus|Obturator internus|Obturator externus)", "hip-rotators{s}"),
    (r"^Rectus femoris", "rectus-femoris{s}"), (r"^Vastus lateralis", "vastus-lateralis{s}"), (r"^Vastus medialis", "vastus-medialis{s}"),
    (r"^Vastus intermedius", "vastus-intermedius{s}"), (r"^Sartorius", "sartorius{s}"),
    (r"^\(?Adductor (magnus|longus|brevis|minimus)|^Pectineus", "adductors{s}"), (r"^Gracilis", "gracilis{s}"),
    (r"head of biceps femoris", "hamstrings-lateral{s}"), (r"^(Semimembranosus|Semitendinosus)", "hamstrings-medial{s}"),
    (r"^Tibialis anterior", "tibialis{s}"),
    (r"^Extensor digitorum longus|^Tendon of extensor digitorum longus|^Extensor hallucis longus|^Fibularis tertius", "toe-extensors{s}"),
    (r"^Fibularis (longus|brevis)", "peroneus{s}"),
    (r"^Lateral head of gastrocnemius", "gastrocnemius-lateral{s}"), (r"^Medial head of gastrocnemius", "gastrocnemius-medial{s}"),
    (r"^Soleus", "soleus{s}"), (r"^Calcaneal tendon", "achilles{s}"), (r"^Plantaris", "plantaris{s}"), (r"^Popliteus", "popliteus{s}"),
    (r"^(Tibialis posterior|Flexor digitorum longus|Flexor hallucis longus)", "leg-deep-flexors{s}"),
    (r"of foot$|hallucis brevis|adductor hallucis|^Abductor hallucis|^Extensor digitorum brevis|^Plantar interossei|"
     r"^Quadratus plantae|^Flexor digitorum brevis", "foot-muscles{s}"),
    (r"^Iliotibial tract", "it-band{s}"),
]

ORGANS = [
    # organ ids (body.json organs) — the real mesh replaces the generated organ
    (r"gyr|sulc|pole$|lobule|Precuneus|^Cuneus|^Insula|Lat_Fis|vermis|^Culmen|^Declive|^Lingula|^Flocculus|^Nodule|"
     r"Tonsil of cerebellum|^Central lobule|^Folium|^Tuber of|^Pyramis|^Midbrain|^Pons$|^Medulla oblongata|^Base of peduncle|"
     r"cerebellar peduncle|^Olive$|^Pyramid of medulla|^Optic chiasm|^Mamillary|^Hypothalamus|colliculus|Peduncle of flocculus", "brain"),
    (r"^(atrium|ventricle)$", "heart"),
    (r"lobe of left lung$", "lung-l"), (r"lobe of right lung$", "lung-r"),
    (r"^Liver$", "liver"), (r"^Stomach$", "stomach"), (r"^Pancreas$", "pancreas"), (r"^Spleen$", "spleen"),
    (r"^Gallbladder$|^Bile duct$", "gallbladder"),
    (r"^(Duodenum|Jejunum|Ascending colon|Transverse colon|Descending colon|Sigmoid colon)$", "intestines"),
    (r"^Vermiform appendix$", "appendix"), (r"^Urinary bladder$", "bladder"),
    (r"^Thyroid gland$|parathyroid gland$", "thyroid"),
    (r"^(Prostate|Seminal gland)$", "prostate"),
    # organ-layer parts
    (r"^Oesophagus$", "esophagus"), (r"^Trachea$|^main bronchus$", "trachea"), (r"bronchus", "bronchus-r"),
    (r"^Ureter$", "ureter{s}"), (r"^(Testis|Epididymis)$", "testis{s}"), (r"^Ductus deferens$", "spermatic-cord{s}"),
    (r"lobe of thymus$", "thymus"), (r"^(Parotid|Sublingual|Submandibular) gland$", "salivary-glands{s}"),
]

VESSELS = [
    (r"^(Ascending aorta|Aortic arch|Thoracic aorta|Abdominal aorta|Brachiocephalic trunk|Median sacral artery|Superior phrenic arteries|Inferior phrenic artery)$", "aorta"),
    (r"^(Pulmonary trunk|Bifurcation of pulmonary trunk|pulmonary artery)$|artery of (right|left) lung$|lingular artery", "pulmonary-arteries"),
    (r"vein of right lung|right .*pulmonary vein|^(superior|inferior) pulmonary vein$", "pulmonary-veins-r"),
    (r"vein of left lung|left .*pulmonary vein", "pulmonary-veins-l"),
    (r"^(Left coronary artery|Circumflex artery of heart|Anterior interventricular artery|Septal branches of anterior interventricular artery)$", "coronary-l"),
    (r"^(Right coronary artery|Right inferolateral branch of right coronary artery|coronary artery)$", "coronary-r"),
    (r"cardiac vein|^Coronary sinus|vein of left ventricle|^\?+$", "cardiac-veins"),
    (r"^(common carotid artery|Internal carotid artery)$", "carotid{s}"),
    (r"^(Superficial temporal artery|Frontal branch of superficial temporal artery)$", "temporal-artery{s}"),
    (r"ophthalmic|retinal|ciliary|ethmoidal|^Lacrimal artery|^Supra-orbital|^Supratrochlear", None),
    (r"^(External carotid|Facial artery|Occipital artery|Ascending pharyngeal|Transverse facial|Maxillary artery|Middle meningeal|"
     r"Accessory branch of middle meningeal|.*alveolar artery|.*deep temporal artery|Artery of pterygoid canal|.*sphenopalatine|"
     r"Buccal artery|Infra-orbital artery|Greater palatine|Descending palatine|Mental branch|Mylohyoid branch|\?x)", "external-carotid{s}"),
    (r"^Vertebral artery$", "vertebral-artery{s}"),
    (r"cerebral|communicating artery|callosomarginal|pericallosal|striate|^Insular branches|temporal branch|^Branch to angular|"
     r"Temporo-occipital|Prefrontal|frontobasal|Posterior parietal artery|Artery of (pre)?central sulcus|Postcentral arterial|"
     r"Parietal branches|^Basilar artery|cerebellar artery|pontine branches|^(Lateral|Medial) occipital artery|Parieto-occipital|"
     r"Anterior spinal artery", "cerebral-arteries"),
    (r"^(subclavian artery|Axillary artery|Brachial artery|Thyrocervical|Costocervical|Suprascapular artery|.*transverse cervical artery|"
     r"Inferior thyroid artery|Deep cervical artery|Supreme intercostal|First posterior intercostal|Second posterior intercostal|"
     r"Thoraco-acromial|Pectoral branches of thoraco|Lateral thoracic artery|Subscapular artery|Thoracodorsal artery|"
     r"Circumflex scapular artery|.*circumflex humeral artery|Deep brachial|.*collateral artery|Common interosseous|"
     r"Posterior interosseous artery|Recurrent interosseous|\(?Ulnar recurrent)", "arm-artery{s}"),
    (r"^(Radial artery|Palmar carpal branch of radial)", "radial-artery{s}"),
    (r"^Ulnar artery", "ulnar-artery{s}"),
    (r"palmar arch|metacarpal arteries|digital arteries of hand|palmar digital arteries|Dorsal carpal", "hand-arteries{s}"),
    (r"^(Internal thoracic artery|Musculophrenic artery|Superior epigastric artery|Posterior intercostal arteries|Subcostal artery|Lumbar arteries)$", "intercostal-arteries{s}"),
    (r"^(Coeliac trunk|Splenic artery|Common hepatic artery|Proper hepatic artery|Left gastric artery|Gastroduodenal artery|Anterior inferior pancreaticoduodenal artery)$", "celiac-trunk"),
    (r"^(Superior mesenteric artery|Ileocolic artery|.*of ileocolic artery|Appendicular artery|Right colic artery|Middle colic artery|Marginal artery|Inferior pancreaticoduodenal artery)$", "mesenteric-artery"),
    (r"^(Inferior mesenteric artery|Left colic artery|.*branch of left colic artery|Sigmoid arteries|Superior anorectal artery)$", "inferior-mesenteric-artery"),
    (r"^renal artery$", "renal-artery{s}"), (r"^renal vein$", "renal-vein{s}"),
    (r"^(Common iliac artery|External iliac artery|Inferior epigastric artery|Femoral artery|.*genicular artery|Patellar anastomosis)$", "leg-artery{s}"),
    (r"^(Internal iliac artery|.*division of internal iliac artery|Superior gluteal artery|Inferior gluteal artery|Obturator artery|"
     r"Internal pudendal artery|Iliolumbar artery|.*branch of iliolumbar artery)$", "internal-iliac{s}"),
    (r"^Perforating (femoral arteries|veins)$", None),
    (r"circumflex femoral artery", "deep-femoral{s}"),
    (r"^(Anterior tibial artery|Dorsalis pedis|Arcuate artery|Deep plantar artery|Lateral tarsal artery|Dorsal metatarsal arteries|Dorsal digital arteries of foot)$", "anterior-tibial{s}"),
    (r"^(Posterior tibial artery|Fibular artery|Calcaneal branches|.*plantar artery|Superficial branch of medial plantar|Plantar arch|"
     r"Plantar metatarsal arteries|Perforating branches of plantar|.*plantar digital arteries)", "posterior-tibial{s}"),
    (r"^(Superior vena cava|Inferior vena cava.*|Hepatic veins|brachiocephalic vein)$", "vena-cava"),
    (r"^Internal jugular vein$|^Vertebral vein$", "jugular{s}"),
    (r"^(External jugular|Anterior jugular|Facial vein|Common facial|Retromandibular|.*division of retromandibular|Superficial temporal veins|"
     r"Maxillary veins|Posterior auricular vein|Occipital vein|Lingual vein|Superior thyroid vein|.*ophthalmic vein)", "external-jugular{s}"),
    (r"sinus$|sinus\b|Basilar venous plexus", "dural-sinuses"),
    (r"^(subclavian vein|Axillary vein|Brachial veins|Radial veins|Ulnar veins|.*circumflex humeral vein|Lateral thoracic vein|"
     r"Thoracodorsal vein|Circumflex scapular vein|Subscapular vein|Suprascapular vein)$", "arm-vein{s}"),
    (r"^Cephalic vein$", "cephalic-vein{s}"), (r"^Basilic vein$", "basilic-vein{s}"),
    (r"^(Median cubital vein|Median antebrachial vein)$", "median-cubital-vein{s}"),
    (r"digital veins of hand|venous network of hand|venous palmar arch|^Palmar digital veins", "hand-veins{s}"),
    (r"^(Azygos vein|Hemi-azygos vein|Accessory hemi-azygos vein|ascending lumbar vein|subcostal vein|superior phrenic vein)$", "azygos-veins"),
    (r"^(superior intercostal vein|Internal thoracic veins|Musculophrenic veins|Superior epigastric veins|Lumbar veins)$", "intercostal-veins{s}"),
    (r"^(Common iliac vein|External iliac vein|Inferior epigastric vein|Superficial epigastric vein|External pudendal veins|Femoral vein|"
     r"Genicular veins|Anterior tibial veins|Posterior tibial veins|Fibular veins|.*plantar veins|Plantar venous arch|"
     r"Plantar metatarsal veins|Plantar digital veins)$", "leg-vein{s}"),
    (r"^(Internal iliac vein|.*gluteal veins|Lateral sacral veins|Internal pudendal vein|Iliolumbar vein)$", "pelvic-veins{s}"),
    (r"^Small saphenous vein$", "small-saphenous{s}"),
    (r"^(Dorsal venous arch of foot|Intercapitular veins of foot|Dorsal metatarsal veins|Dorsal digital veins of foot)$", "foot-veins{s}"),
    (r"^(Hepatic portal vein|Superior mesenteric vein|Inferior mesenteric vein|Splenic vein|.*colic vein|.*gastro-omental vein|Sigmoid veins)$", "portal-vein"),
]

NERVES = [
    (r"^White matter of spinal cord$|^Cauda equina$", "spinal-cord"),
    (r"brachial plexus|^(Dorsal scapular|Long thoracic|Suprascapular|Subclavian|.*pectoral|.*subscapular|Thoracodorsal) nerve$|"
     r"^Axillary nerve|of axillary nerve$|^Musculocutaneous|^Lateral antebrachial cutaneous|^Medial (brachial|antebrachial) cutaneous|"
     r"of medial antebrachial cutaneous nerve$|median nerve|^Anterior interosseous nerve", "arm-nerve{s}"),
    (r"ulnar nerve", "ulnar-nerve{s}"),
    (r"radial nerve|^Posterior interosseous nerve|^Posterior antebrachial cutaneous|lateral brachial cutaneous", "radial-nerve{s}"),
    (r"^Intercostal nerves$", "intercostal-nerves{s}"),
    (r"^(Iliohypogastric|Ilio-inguinal|Genitofemoral|Lateral femoral cutaneous)|of genitofemoral nerve$", "lumbar-plexus{s}"),
    (r"^Femoral nerve$|of femoral nerve$|saphenous nerve", "femoral-nerve{s}"),
    (r"obturator nerve", "obturator-nerve{s}"),
    (r"^Sciatic nerve$", "sciatic{s}"),
    (r"gluteal nerve|^Nerve to (piriformis|quadratus femoris)|^Pudendal nerve|posterior femoral cutaneous", "sacral-plexus{s}"),
    (r"^Tibial nerve$|plantar nerve|^Medial sural cutaneous|^Sural nerve$", "tibial-nerve{s}"),
    (r"fibular nerve|dorsal cutaneous nerve of foot|^Sural communicating", "common-peroneal{s}"),
    (r"^Vagus nerve", "vagus{s}"), (r"^Facial nerve", "facial-nerve{s}"),
    (r"^(Olfactory|Optic|Oculomotor|Trochlear|Abducens|Trigeminal|Glossopharyngeal|Accessory|Hypoglossal) nerve|trigeminal nerve$|"
     r"^(Ophthalmic|Maxillary|Lingual|Inferior alveolar|Mental|Buccal) nerve$|division of mandibular nerve|^Nerve to mylohyoid|"
     r"^Meningeal branch of maxillary", "cranial-nerves{s}"),
    (r"^Sympathetic trunk$|^Ganglia of sympathetic trunk$", "sympathetic-trunk{s}"),
    (r"root of spinal nerve$|^Spinal ganglion$", "spinal-nerves{s}"),
]

# limb tubes are cut where the app's age reshaping switches region (|x| = 0.316 arm, y = -0.04 leg):
# id → (trunk piece, limb piece), so each piece scales with its own region for children
SPLIT = {
    "arm-artery": ("arm-artery", "arm-artery-2"), "arm-vein": ("arm-vein", "arm-vein-2"),
    "arm-nerve": ("arm-nerve", "arm-nerve-2"), "cephalic-vein": ("cephalic-vein-2", "cephalic-vein"),
    "leg-artery": ("leg-artery", "leg-artery-2"), "leg-vein": ("leg-vein", "leg-vein-2"),
    "sciatic": ("sciatic", "sciatic-2"), "femoral-nerve": ("femoral-nerve", "femoral-nerve-2"),
}
ARM_X, LEG_Y = 0.316, -0.04
# rectus abdominis bands between its tendinous intersections (scene y of the generated segments' tops)
RECTUS_CUTS = [0.5762, 0.446, 0.3158]

# ids not in body.json: (name, 中文, colour)
NEW = {
    "occipitalis": ("Occipitalis", "枕肌", MUSCLE), "epicranial-aponeurosis": ("Epicranial aponeurosis", "帽状腱膜", TENDON),
    "facial-muscles": ("Facial expression muscles", "面部表情肌", MUSCLE),
    "suprahyoid": ("Suprahyoid muscles", "舌骨上肌群", MUSCLE), "infrahyoid": ("Infrahyoid muscles", "舌骨下肌群", MUSCLE),
    "scalenes": ("Scalene muscles", "斜角肌", MUSCLE), "splenius": ("Splenius", "夹肌", MUSCLE),
    "levator-scapulae": ("Levator scapulae", "肩胛提肌", MUSCLE), "rhomboids": ("Rhomboids", "菱形肌", MUSCLE),
    "serratus-posterior": ("Serratus posterior", "后锯肌", MUSCLE),
    "transversospinales": ("Semispinalis & multifidus", "半棘肌与多裂肌", MUSCLE),
    "linea-alba": ("Linea alba", "白线", TENDON),
    "pectoralis-minor": ("Pectoralis minor", "胸小肌", MUSCLE), "intercostals": ("External intercostals", "肋间外肌", MUSCLE),
    "internal-oblique": ("Internal oblique", "腹内斜肌", MUSCLE), "quadratus-lumborum": ("Quadratus lumborum", "腰方肌", MUSCLE),
    "pelvic-floor": ("Pelvic floor (levator ani)", "盆底肌（肛提肌）", MUSCLE),
    "supraspinatus": ("Supraspinatus", "冈上肌", MUSCLE), "infraspinatus": ("Infraspinatus", "冈下肌", MUSCLE),
    "teres-minor": ("Teres minor", "小圆肌", MUSCLE), "teres-major": ("Teres major", "大圆肌", MUSCLE),
    "subscapularis": ("Subscapularis", "肩胛下肌", MUSCLE), "coracobrachialis": ("Coracobrachialis", "喙肱肌", MUSCLE),
    "iliopsoas": ("Iliopsoas", "髂腰肌", MUSCLE), "gluteus-minimus": ("Gluteus minimus", "臀小肌", MUSCLE),
    "hip-rotators": ("Deep hip rotators", "髋深部外旋肌", MUSCLE), "vastus-intermedius": ("Vastus intermedius", "股中间肌", MUSCLE),
    "toe-extensors": ("Long toe extensors", "趾长伸肌", MUSCLE), "plantaris": ("Plantaris", "跖肌", MUSCLE),
    "popliteus": ("Popliteus", "腘肌", MUSCLE), "leg-deep-flexors": ("Deep calf muscles", "小腿深层屈肌", MUSCLE),
    "foot-muscles": ("Foot muscles", "足部肌", MUSCLE),
    "prostate": ("Prostate", "前列腺", "#C98A8A"), "thymus": ("Thymus", "胸腺", "#D9B8A0"),
    "salivary-glands": ("Salivary glands", "唾液腺", "#D9A88A"),
    "cardiac-veins": ("Cardiac veins", "心静脉", VEIN), "cerebral-arteries": ("Cerebral arteries", "脑动脉", ARTERY),
    "inferior-mesenteric-artery": ("Inferior mesenteric artery", "肠系膜下动脉", ARTERY),
    "external-jugular": ("External jugular & facial veins", "颈外静脉与面静脉", VEIN),
    "dural-sinuses": ("Dural venous sinuses", "硬脑膜静脉窦", VEIN),
    "median-cubital-vein": ("Median cubital vein", "肘正中静脉", VEIN), "hand-veins": ("Hand veins", "手部静脉", VEIN),
    "azygos-veins": ("Azygos veins", "奇静脉", VEIN), "pelvic-veins": ("Internal iliac veins", "髂内静脉", VEIN),
    "small-saphenous": ("Small saphenous vein", "小隐静脉", VEIN), "foot-veins": ("Foot veins", "足部静脉", VEIN),
    "portal-vein": ("Hepatic portal vein", "肝门静脉", "#5B4FB0"),
    "lumbar-plexus": ("Lumbar plexus nerves", "腰丛神经", NERVE), "obturator-nerve": ("Obturator nerve", "闭孔神经", NERVE),
    "sacral-plexus": ("Gluteal & pudendal nerves", "臀神经与阴部神经", NERVE),
    "cranial-nerves": ("Cranial nerves", "脑神经", NERVE), "sympathetic-trunk": ("Sympathetic trunk", "交感干", NERVE),
}
SEX = {"prostate": "male", "testis": "male", "spermatic-cord": "male"}
# generated parts kept alongside the real ones (no Z-Anatomy counterpart)
KEEP = re.compile(r"^(eyeball-|great-saphenous)")


def split_side(name):
    """'Femoral artery.l' → ('Femoral artery', 'l'); 'Left renal artery' → ('renal artery', 'l')."""
    name = re.sub(r"\.\d{3}$", "", name).strip()
    if m := re.match(r"(.+)\.([lr])$", name):
        return m[1], m[2]
    if m := re.match(r"(Left|Right) (.+)$", name):
        return m[2], m[1][0].lower()
    return name, ""


def our_id(name, rules):
    base, side = split_side(name)
    for pat, pid in rules:
        if re.search(pat, base, re.I):
            if pid is None:
                return None
            if "{s}" in pid:
                return pid.replace("{s}", f"-{side}") if side else None
            return pid
    return None


def names_for(pid, body_parts, organs):
    if pid in body_parts:
        p = body_parts[pid]
        return p["name"], p["nameZh"], p["color"]
    if pid in organs:
        o = organs[pid]
        return o["names"][0], o["names"][1], o["color"]
    base, side = (pid[:-2], pid[-1]) if re.search(r"-[lr]$", pid) else (pid, "")
    name, zh, color = NEW[base]
    if side:
        name += f" ({side.upper()})"
        zh = ("左" if side == "l" else "右") + zh
    return name, zh, color


# ------------------------------------------------------------------ geometry (numpy)


def tri_arrays(np, me):
    me.calc_loop_triangles()
    f = np.empty(len(me.loop_triangles) * 3, dtype=np.int32)
    me.loop_triangles.foreach_get("vertices", f)
    return bm.mesh_coords(np, me), f.reshape(-1, 3)


def area(np, v, f):
    return float(np.linalg.norm(np.cross(v[f[:, 1]] - v[f[:, 0]], v[f[:, 2]] - v[f[:, 0]]), axis=1).sum() / 2)


def normals(np, v, f):
    fn = np.cross(v[f[:, 1]] - v[f[:, 0]], v[f[:, 2]] - v[f[:, 0]])
    n = np.zeros_like(v)
    for i in range(3):
        np.add.at(n, f[:, i], fn)
    return n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)


def subset(np, v, f, keep):
    """faces where keep is True, with only their vertices"""
    f = f[keep]
    used = np.unique(f)
    remap = np.full(len(v), -1, dtype=np.int32)
    remap[used] = np.arange(len(used))
    return v[used], remap[f]


def fibre_uv(np, v, f):
    """Cylindrical UVs about the part's long axis: u around (stripes = fibres along the length), v along."""
    c = v.mean(0)
    _, _, axes = np.linalg.svd(v - c, full_matrices=False)
    d = v - c
    along = d @ axes[0]
    vv = (along - along.min()) / max(along.max() - along.min(), 1e-9)
    a2, a3 = d @ axes[1], d @ axes[2]
    uu = np.arctan2(a3, a2) / (2 * math.pi) + 0.5
    # repeat the 8-stripe texture on wide parts so fibres stay ~3 cm apart
    girth = 2 * math.pi * float(np.sqrt(a2 ** 2 + a3 ** 2).mean())
    reps = max(1, round(girth / 0.25))
    # faces straddling the seam get their low-u corners duplicated at u + 1
    fu = uu[f]
    wrap = (fu.max(1) - fu.min(1)) > 0.5
    v, uu, vv, f = v.copy(), uu.copy(), vv.copy(), f.copy()
    extra = {}
    for fi in np.nonzero(wrap)[0]:
        for k in range(3):
            i = f[fi, k]
            if uu[i] < 0.5:
                if i not in extra:
                    extra[i] = len(v) + len(extra)
                f[fi, k] = extra[i]
    if extra:
        idx = np.array(list(extra.keys()))
        v = np.concatenate([v, v[idx]])
        uu = np.concatenate([uu, uu[idx] + 1])
        vv = np.concatenate([vv, vv[idx]])
    return v, f, np.stack([uu * reps, vv], axis=1)


# ------------------------------------------------------------------ warp: each vertex follows its nearest bones


class Warp:
    def __init__(self, np, bpy):
        from mathutils.kdtree import KDTree
        self.np = np
        pieces, segment, src, top_src = bm.skeleton_source(bpy, np)
        self.fit, self.s = bm.fitter(np, src, top_src, 0.0, "bone")
        clouds = {}
        for pid, items in pieces.items():
            seg = segment[pid]
            key = "trunk" if seg is None else f"{seg}-{pid[-1]}"
            clouds.setdefault(key, []).extend(p[1] for p in items)
        rng = np.random.default_rng(1)
        self.keys, self.trees = sorted(clouds), []
        for k in self.keys:
            pts = np.concatenate(clouds[k])
            if len(pts) > 6000:
                pts = pts[rng.choice(len(pts), 6000, replace=False)]
            t = KDTree(len(pts))
            for i, p in enumerate(pts):
                t.insert(p, i)
            t.balance()
            self.trees.append(t)
        for items in pieces.values():
            for _, _, me in items:
                bpy.data.meshes.remove(me)

    def weights(self, raw):
        np = self.np
        d = np.empty((len(raw), len(self.keys)))
        pts = raw.tolist()
        for j, t in enumerate(self.trees):
            find = t.find
            d[:, j] = [find(p)[2] for p in pts]
        w = np.exp(-(d - d.min(1, keepdims=True)) / SIGMA)
        w[w < 0.03] = 0
        return w / w.sum(1, keepdims=True)

    def apply(self, raw, trunk_only=False):
        """raw scene coords (metres) → body coords, plus each segment's share of the weights"""
        np = self.np
        if trunk_only:
            return self.fit(raw, "trunk"), {"trunk": 1.0}
        w = self.weights(raw)
        out = np.zeros_like(raw)
        for j, k in enumerate(self.keys):
            sel = w[:, j] > 0
            if sel.any():
                out[sel] += self.fit(raw[sel], k) * w[sel, j:j + 1]
        share = {k: float(w[:, j].sum() / len(raw)) for j, k in enumerate(self.keys)}
        return out, share


class SkinClamp:
    """Moves the muscles that stick out of an adult skin figure (Resources/Models/skin-*.usdz) back under it.

    Z-Anatomy's man is more muscular than the MakeHuman figures (chest, flanks, shoulders); without this the
    pectorals and serratus show through the glass skin. Outside vertices slide horizontally towards their
    part's bone line (trunk: the body's vertical axis); the move is spread over everything nearby so layered
    muscles move together.
    Re-run after the skins change."""

    MARGIN = 0.006  # scene units (~3 mm)
    RADIUS, SPREAD = 0.06, 0.03
    RAYS = ((1, 0, 0), (-1, 0, 0), (0, 0, 1))

    def __init__(self, np):
        from mathutils.bvhtree import BVHTree
        from pxr import Usd, UsdGeom
        self.np, self.trees = np, {}
        for sex in ("male", "female"):
            f = OUT / f"skin-{sex}.usdz"
            if not f.exists():
                continue
            stage = Usd.Stage.Open(str(f))
            body = next((p for p in stage.Traverse() if p.GetName() == "body" and p.IsA(UsdGeom.Mesh)), None)
            if body is None:
                continue
            m = UsdGeom.Mesh(body)
            pts = bm.to_scene(np, np.array(m.GetPointsAttr().Get(), dtype=float))
            counts, idx = list(m.GetFaceVertexCountsAttr().Get()), list(m.GetFaceVertexIndicesAttr().Get())
            polys, i = [], 0
            for c in counts:
                polys.append(tuple(idx[i:i + c]))
                i += c
            self.trees[sex] = BVHTree.FromPolygons(pts.tolist(), polys)

    @staticmethod
    def inside(tree, p):
        from mathutils import Vector
        votes = 0
        for d in SkinClamp.RAYS:
            d, o, hits = Vector(d), Vector(p), 0
            while hits < 20:
                loc, _, _, _ = tree.ray_cast(o, d)
                if loc is None:
                    break
                hits += 1
                o = loc + d * 1e-5
            votes += hits % 2
        return votes >= 2

    def push(self, tree, p, a, b):
        """displacement taking outside point p just inside, towards its part's axis a-b; None if that fails"""
        np = self.np
        ab = b - a
        q = a + ab * np.clip(np.dot(p - a, ab) / np.dot(ab, ab), 0, 1)
        span = float(np.linalg.norm(q - p))
        if span < 1e-6 or not self.inside(tree, q):
            return None
        lo, hi = 0.0, 1.0  # lo outside, hi inside
        for _ in range(9):
            mid = (lo + hi) / 2
            lo, hi = (lo, mid) if self.inside(tree, p + (q - p) * mid) else (mid, hi)
        return (q - p) * min(1.0, hi + self.MARGIN / span)

    def __call__(self, sex, parts, axes):
        """parts: [vertex arrays], axes: [(a, b)] each part's bone line → parts moved inside this sex's skin"""
        from mathutils.kdtree import KDTree
        np = self.np
        tree = self.trees.get(sex)
        if tree is None or not parts:
            return parts
        v = np.concatenate(parts)
        owner = np.concatenate([np.full(len(p), k) for k, p in enumerate(parts)])
        # face, hands and feet hug the skin and the figures' fingers differ: only the body and limbs are clamped
        x, y = np.abs(v[:, 0]), v[:, 1]
        region = np.nonzero((y < 1.2) & (y > -1.4) & ~((x > 0.36) & (y < 0.1)))[0]
        for step in range(4):
            idx, disp = [], []
            for i in region:
                if not self.inside(tree, v[i]):
                    d = self.push(tree, v[i], *axes[owner[i]])
                    if d is not None:
                        idx.append(i)
                        disp.append(d)
            print(f"INTERNALS clamp {sex} pass {step}: {len(idx)} vertices outside")
            if not idx:
                break
            kd = KDTree(len(idx))
            for k, i in enumerate(idx):
                kd.insert(v[i], k)
            kd.balance()
            disp = np.array(disp)
            move = np.zeros_like(v)
            for i in region:
                hits = kd.find_range(v[i], self.RADIUS)
                if hits:
                    w = np.exp(-(np.array([h[2] for h in hits]) / self.SPREAD) ** 2)
                    move[i] = (w[:, None] * disp[[h[1] for h in hits]]).sum(0) / (w.sum() + 0.25)
            v = v + move
        out, n = [], 0
        for p in parts:
            out.append(v[n:n + len(p)])
            n += len(p)
        return out


JOINT_OF = {"uparm": "shoulder", "forearm": "elbow", "hand": "elbow", "shin": "knee", "foot": "knee"}


def joint_for(share):
    key = max(share, key=share.get)
    seg, _, side = key.partition("-")
    # pieces spanning a joint (femoral → tibial veins) would swing out whole: they stay put instead
    return f"{JOINT_OF[seg]}-{side}" if seg in JOINT_OF and share[key] > 0.75 else None


# ------------------------------------------------------------------ Blender side


def collect(bpy, np, collections, rules, layer):
    """{id: [(object, evaluated mesh in world coords)]} for every object the rules map"""
    dg = bpy.context.evaluated_depsgraph_get()
    out = {}
    seen = set()
    for cn in collections:
        for o in bpy.data.collections[cn].objects:
            if o.name in seen or o.type not in ("MESH", "CURVE") or NC.search(o.name):
                continue
            seen.add(o.name)
            pid = our_id(o.name, rules)
            if not pid:
                continue
            if o.type == "CURVE" and layer in MIN_RADIUS:
                tube_settings(o.data, MIN_RADIUS[layer])
                dg.update()
            elif o.type == "CURVE":
                o.data.resolution_u = min(o.data.resolution_u, 4)
                o.data.bevel_resolution = min(o.data.bevel_resolution, 2)
                dg.update()
            try:
                me = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
            except RuntimeError:
                continue
            if not len(me.polygons):
                bpy.data.meshes.remove(me)
                continue
            me.transform(o.matrix_world)
            # mirrored clones (negative scale) come out inside-out
            out.setdefault(pid, []).append((o.matrix_world.determinant() < 0, me))
    return out


def tube_settings(d, rmin):
    """thin, low-sided tubes: 6 sides (8 for the big trunks), 2 rings per Bézier span, radius ≥ rmin"""
    depth = max(d.bevel_depth, 1e-6)
    big = 0.0
    for s in d.splines:
        for p in (s.bezier_points if s.type == "BEZIER" else s.points):
            p.radius = max(p.radius, rmin / depth)
            big = max(big, p.radius * depth)
    # 4 sides read as round at phone size when thin; 6 for mid-size, 8 for the great vessels
    d.bevel_resolution = 2 if big > 0.004 else 1 if big > 0.0022 else 0
    d.resolution_u = 2 if big > 0.004 else 1
    d.use_fill_caps = big > 0.004


def joined(bpy, np, items):
    vs, fs, n = [], [], 0
    for mirrored, me in items:
        v, f = tri_arrays(np, me)
        if mirrored:
            f = f[:, ::-1]
        vs.append(v)
        fs.append(f + n)
        n += len(v)
        bpy.data.meshes.remove(me)
    return np.concatenate(vs), np.concatenate(fs)


def remesh(bpy, np, v, f, voxel):
    """one closed surface through many touching pieces (the brain's gyrus patches)"""
    me = bpy.data.meshes.new("remesh")
    me.from_pydata(v.tolist(), [], f.tolist())
    me.update()
    ob = bpy.data.objects.new("remesh", me)
    bpy.context.scene.collection.objects.link(ob)
    mod = ob.modifiers.new("r", "REMESH")
    mod.mode = "VOXEL"
    mod.voxel_size = voxel
    dg = bpy.context.evaluated_depsgraph_get()
    dg.update()
    me2 = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    out = tri_arrays(np, me2)
    bpy.data.objects.remove(ob)
    bpy.data.meshes.remove(me)
    bpy.data.meshes.remove(me2)
    return out


def decimate(bpy, np, v, f, target):
    if len(f) <= target:
        return v, f
    me = bpy.data.meshes.new("dec")
    me.from_pydata(v.tolist(), [], f.tolist())
    me.update()
    ob = bpy.data.objects.new("dec", me)
    bpy.context.scene.collection.objects.link(ob)
    mod = ob.modifiers.new("d", "DECIMATE")
    mod.ratio = target / len(f)
    mod.use_collapse_triangulate = True
    dg = bpy.context.evaluated_depsgraph_get()
    dg.update()
    me2 = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    out = tri_arrays(np, me2)
    bpy.data.objects.remove(ob)
    bpy.data.meshes.remove(me)
    bpy.data.meshes.remove(me2)
    return out


def write_usdz(np, parts, path):
    """parts: [(id, v scene coords, f, uv or None)] → usdz, Z-up like Blender's export (skeleton.usdz)"""
    from pxr import Gf, Sdf, Usd, UsdGeom, UsdUtils, Vt
    usdc = ROOT / "build" / "models" / (path.stem + ".usdc")
    usdc.parent.mkdir(parents=True, exist_ok=True)
    if usdc.exists():
        usdc.unlink()
    stage = Usd.Stage.CreateNew(str(usdc))
    UsdGeom.SetStageUpAxis(stage, UsdGeom.Tokens.z)
    UsdGeom.SetStageMetersPerUnit(stage, 1.0)
    root = UsdGeom.Xform.Define(stage, "/root")
    stage.SetDefaultPrim(root.GetPrim())
    for pid, v, f, uv in parts:
        b = bm.to_blender(np, v).astype(np.float32)
        m = UsdGeom.Mesh.Define(stage, f"/root/{bm.prim(pid)}")
        m.CreatePointsAttr(Vt.Vec3fArray.FromNumpy(b))
        m.CreateFaceVertexCountsAttr(Vt.IntArray.FromNumpy(np.full(len(f), 3, dtype=np.int32)))
        m.CreateFaceVertexIndicesAttr(Vt.IntArray.FromNumpy(f.reshape(-1).astype(np.int32)))
        m.CreateNormalsAttr(Vt.Vec3fArray.FromNumpy(normals(np, b.astype(np.float64), f).astype(np.float32)))
        m.SetNormalsInterpolation(UsdGeom.Tokens.vertex)
        m.CreateSubdivisionSchemeAttr(UsdGeom.Tokens.none)
        m.CreateExtentAttr(Vt.Vec3fArray([Gf.Vec3f(*map(float, b.min(0))), Gf.Vec3f(*map(float, b.max(0)))]))
        if uv is not None:
            pv = UsdGeom.PrimvarsAPI(m).CreatePrimvar("st", Sdf.ValueTypeNames.TexCoord2fArray, UsdGeom.Tokens.vertex)
            pv.Set(Vt.Vec2fArray.FromNumpy(uv.astype(np.float32)))
    stage.GetRootLayer().Save()
    if path.exists():
        path.unlink()
    UsdUtils.CreateNewUsdzPackage(Sdf.AssetPath(str(usdc)), str(path))


# ------------------------------------------------------------------ build


def build():
    import bpy
    import numpy as np

    body = json.loads((ROOT / "Resources/Data/body.json").read_text())
    body_parts = {p["id"]: p for p in body["parts"]}
    organs = {o["id"]: o for o in body["organs"] if o.get("names")}
    warp = Warp(np, bpy)
    clamp = SkinClamp(np)
    print("INTERNALS warp scale", round(warp.s, 4), "skins", sorted(clamp.trees))
    plan = [
        ("muscular", ["4: Muscular system"], MUSCLES),
        ("organs", ["5: Cardiovascular system", "6: Lymphoid organs", "7: Nervous system & Sense organs", "8: Visceral systems"], ORGANS),
        ("circulatory", ["5: Cardiovascular system"], VESSELS),
        ("nervous", ["7: Nervous system & Sense organs"], NERVES),
    ]
    entries, total, files = [], 0, {}
    for layer, cols, rules in plan:
        got = collect(bpy, np, cols, rules, layer)
        meshes = {pid: joined(bpy, np, items) for pid, items in got.items()}
        # decimation budget by surface area (tubes are already light)
        if layer in BUDGET:
            areas = {pid: area(np, *vf) ** 0.8 for pid, vf in meshes.items() if pid != "brain"}
            whole = sum(areas.values())
            for pid, (v, f) in meshes.items():
                if pid == "brain":
                    # the cortex comes as ~150 gyrus / sulcus patches: remesh them into one surface first
                    meshes[pid] = decimate(bpy, np, *remesh(bpy, np, v, f, 0.0012), BRAIN_TRIS)
                    continue
                target = int(min(6000, max(160 if layer == "muscular" else 300, BUDGET[layer] * areas[pid] / whole)))
                meshes[pid] = decimate(bpy, np, v, f, target)
        else:
            # mesh-built pieces (dural sinuses, spinal cord, ganglia) would outweigh whole limbs of tubes
            for pid, (v, f) in meshes.items():
                meshes[pid] = decimate(bpy, np, v, f, TUBE_CAP.get(pid, 3500))
        out = []
        order = sorted(meshes)
        fitted, share = {}, {}
        for pid in order:
            fitted[pid], share[pid] = warp.apply(bm.to_scene(np, meshes[pid][0]), trunk_only=layer == "organs")
        variants = {pid: {"": fitted[pid]} for pid in order}
        if layer == "muscular":
            axes = [segment_axis(np, share[pid]) for pid in order]
            male = clamp("male", [fitted[pid] for pid in order], axes)
            female = clamp("female", male, axes)
            for pid, vm, vf in zip(order, male, female):
                variants[pid] = {"": vm}
                # the female figure is slimmer (chest, flanks): parts it moves get their own copy
                if np.abs(vf - vm).max() > 0.002:
                    variants[pid]["--female"] = vf
        for pid in order:
            f = meshes[pid][1]
            base = pid[:-2] if re.search(r"-[lr]$", pid) else pid
            for suffix, fv in variants[pid].items():
                pieces = [(pid, fv, f)]
                if base in SPLIT:
                    side = pid[-2:]
                    c = fv[f].mean(1)
                    limb = np.abs(c[:, 0]) > ARM_X if base.startswith(("arm", "cephalic")) else c[:, 1] < LEG_Y
                    trunk_id, limb_id = SPLIT[base]
                    pieces = [(trunk_id + side, *subset(np, fv, f, ~limb)), (limb_id + side, *subset(np, fv, f, limb))]
                if base == "rectus-abdominis":
                    c = fv[f].mean(1)[:, 1]
                    band = np.digitize(-c, [-y for y in RECTUS_CUTS])
                    pieces = [(f"rectus-abdominis-{i + 1}{pid[-2:]}", *subset(np, fv, f, band == i)) for i in range(4)]
                for qid, qv, qf in pieces:
                    if not len(qf):
                        continue
                    uv = None
                    if layer in ("muscular", "organs"):
                        qv, qf, uv = fibre_uv(np, qv, qf)
                    out.append((qid + suffix, qv, qf, uv))
                    if suffix:
                        continue
                    name, zh, color = names_for(qid, body_parts, organs)
                    qbase = qid[:-2] if re.search(r"-[lr]$", qid) else qid
                    entry = {"id": qid, "name": name, "nameZh": zh, "layer": layer, "color": color}
                    if qid in organs or qid == "prostate":
                        entry["organ"] = "uterus" if qid == "prostate" else qid
                    if qbase in SEX:
                        entry["sex"] = SEX[qbase]
                    # a limb piece turns with its joint like the bones (organs and trunk pieces stay put)
                    if layer != "organs":
                        joint = joint_for(share[pid] if len(pieces) == 1 else region_share(np, qv))
                        if joint:
                            entry["joint"] = joint
                    entry["tris"] = int(len(qf))
                    entry["file"] = FILES[layer]
                    entries.append(entry)
                    total += len(qf)
        path = OUT / FILES[layer]
        write_usdz(np, out, path)
        files[layer] = FILES[layer]
        tris = sum(len(p[2]) for p in out if "--" not in p[0])
        alt = sum(len(p[2]) for p in out if "--" in p[0])
        print(f"INTERNALS {layer}: {len(out)} meshes, {tris} triangles (+{alt} female variants), {path.stat().st_size / 1024:.0f} KB")
    lo, hi = TOTAL_TRIS
    print(f"INTERNALS total {total} triangles")
    if not lo <= total <= hi:
        print(f"INTERNALS WARNING triangles {total} outside {lo}-{hi}")
    provided = {e["id"] for e in entries}
    replaces = sorted(p["id"] for p in body["parts"]
                      if p["id"] not in provided and p["layer"] in ("muscular", "circulatory", "nervous") and not KEEP.match(p["id"]))
    index = bm.load_index()
    index.pop("internals", None)
    index = {"internals": {"files": files, "source": "Z-Anatomy", "license": "CC BY-SA 4.0", "triangles": total,
                           "replaces": replaces, "parts": entries}, **index}
    bm.save_index(index)


def segment_axis(np, share):
    """line through the bones of a part's main segment, body coords (trunk: vertical through the spine)"""
    key = max(share, key=share.get)
    seg, _, side = key.partition("-")
    g = lambda k: np.array(bm.GEN[k]) * np.array((1 if side == "l" else -1, 1, 1))
    ends = {"uparm": ("shoulder", "elbow"), "forearm": ("elbow", "wrist"), "hand": ("wrist", "finger"),
            "thigh": ("hip", "knee"), "shin": ("knee", "ankle"), "foot": ("ankle", "toe")}
    if seg in ends:
        return g(ends[seg][0]), g(ends[seg][1])
    return np.array((0.0, -0.3, -0.03)), np.array((0.0, 1.5, -0.03))


def region_share(np, fitted):
    """segment of a split piece (already in body coords), from where its centre lies"""
    g = {k: np.array(v) for k, v in bm.GEN.items()}
    c = fitted.mean(0)
    side = "l" if c[0] > 0 else "r"
    if abs(c[0]) > ARM_X:
        if c[1] > g["elbow"][1]:
            return {f"uparm-{side}": 1.0}
        return {f"forearm-{side}": 1.0}
    if c[1] < LEG_Y:
        if c[1] > g["knee"][1]:
            return {f"thigh-{side}": 1.0}
        return {f"shin-{side}": 1.0}
    return {"trunk": 1.0}


if __name__ == "__main__":
    build()
