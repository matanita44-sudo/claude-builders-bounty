extends RefCounted

# Player-facing translations for data-driven content. IDs stay language-neutral so
# balance data and save files never depend on translated copy.
const CONTENT := {
	"boss": {
		"gravemaw": {
			"name": "קרונוס",
			"subtitle": "הקוצר המוזהב",
			"fantasy": "הטיטאן הצעיר והערמומי מניף מגל אדמנט ואוסף את השמיים לקציר בלתי אפשרי."
		},
		"seraph_9": {
			"name": "היפריון",
			"subtitle": "אדון האור הראשון",
			"fantasy": "אבי השמש, הירח והשחר מכופף את האור הראשון לדפוסים יפים ומסוכנים."
		},
		"abyss_leviathan": {
			"name": "אוקיינוס",
			"subtitle": "זרם העולם",
			"fantasy": "טיטאן הנהר המקיף את הארץ הופך את השמיים לזרם מתגלגל של גאות וסערות."
		},
		"null_twin": {
			"name": "מנמוסינה",
			"subtitle": "אם ההדים",
			"fantasy": "טיטאנית הזיכרון, המילים והשפה זוכרת כל תנועה והופכת את סיפור הצולל למבחן האחרון."
		}
	},
	"organ": {
		"hunter_eye": {
			"name": "עין הגורל",
			"effect": "כוכבי המגל מאבדים נעילה ועוברים לקשתות ישרות וקריאות."
		},
		"gravity_lung": {
			"name": "נשימת גאיה",
			"effect": "טבעות הקציר מואטות והפתח הבטוח שלהן מתרחב."
		},
		"bone_forge": {
			"name": "כור האדמנט",
			"effect": "פתחי המגל המוזהבים נאטמים ומפסיקים לשגר להבים."
		},
		"prism_cortex": {
			"name": "תודעת השחר",
			"effect": "רמחי השחר מאבדים קרן מוחזרת אחת ומאירים התרעה ארוכה יותר."
		},
		"wing_reactor": {
			"name": "מעטה השמש",
			"effect": "מעטה קרן אחד מתקפל ומשאיר אגף בטוח קבוע."
		},
		"halo_choir": {
			"name": "כתר השמש",
			"effect": "כתר השמש נסדק והמחסום הזוהר אינו נסגר עוד לחלוטין."
		},
		"vortex_stomach": {
			"name": "לב זרם העולם",
			"effect": "משיכת הגאות נחלשת ומשאירה תעלה רגועה ורחבה בכל גל."
		},
		"shock_gland": {
			"name": "כף הסערה",
			"effect": "קשתות הסערה מפסיקות לשרשר דרך סימני גאות סמוכים."
		},
		"brood_sac": {
			"name": "מעיינות הנהר",
			"effect": "מעיינות הנהר נסגרים ורוחות גל חדשות מפסיקות להצטרף לקרב."
		},
		"memory_cortex": {
			"name": "כתר הזיכרון",
			"effect": "מנמוסינה שוכחת את הנשק המצויד ומפסיקה להעתיק את יריותיו."
		},
		"echo_heart": {
			"name": "לב ההד",
			"effect": "נתיבי ההד דועכים; התאום אינו יכול עוד לשחזר את הזינוק האחרון."
		},
		"reflection_lattice": {
			"name": "צעיף המוזות",
			"effect": "פסוקים מזויפים נעלמים ונקודת התורפה האלוהית נשארת גלויה."
		}
	},
	"weapon": {
		"pulse_needle": {
			"name": "ניצוץ איון",
			"description": "האור האחרון של האל משיב לידיים ריקות ביריות מהירות ומדויקות.",
			"weakness": "ללא שליטה בקהל."
		},
		"scatter_maw": {
			"name": "לוע מתפזר",
			"description": "מטווח אכזרי של חמש שיניים לצלילות קרובות וחסרות פחד.",
			"weakness": "הנזק דועך בטווח רחוק."
		},
		"rail_spine": {
			"name": "שדרת מסילה",
			"description": "רומח שדרה איטי שחודר שריון והמונים.",
			"weakness": "כל החטאה יקרה."
		},
		"arc_swarm": {
			"name": "נחיל קשת",
			"description": "ניצוצות חיים מדלגים בין מגינים פנימיים סמוכים.",
			"weakness": "חלש יותר מול מטרה חיצונית בודדת."
		},
		"void_orbitals": {
			"name": "לווייני הריק",
			"description": "להבים במסלול צמוד מוחקים קליעים וקורעים רקמה סמוכה.",
			"weakness": "דורש מיקום מסוכן."
		}
	},
	"mutation": {
		"split_chamber": {
			"name": "תא מפוצל",
			"description": "יורים שתי מחטים צדדיות. כל ירייה גורמת 18% פחות נזק."
		},
		"phase_wake": {
			"name": "שובל פאזה",
			"description": "זינוק פאזה משאיר שובל מזיק למשך 1.2 שניות."
		},
		"hungry_orbit": {
			"name": "מסלול רעב",
			"description": "מקבלים לוויין אחד שבולע יריות אויב וגדל במהלך הריצה."
		},
		"needle_through_bone": {
			"name": "מחט דרך עצם",
			"description": "יריות חודרות מטרה אחת וגורמות 30% יותר נזק לשריון."
		},
		"last_pulse": {
			"name": "פעימה אחרונה",
			"description": "מתחת ל־35% גוף, קצב האש עולה ב־55%."
		},
		"parasite_leech": {
			"name": "עלוקת טפיל",
			"description": "כל חיסול פנימי חמישי מתקן 4 נקודות גוף."
		},
		"core_resonance": {
			"name": "תהודת ליבה",
			"description": "כל איבר שמושמד מוסיף 12% נזק לריצה הנוכחית."
		},
		"glass_engine": {
			"name": "מנוע זכוכית",
			"description": "גורמים 48% יותר נזק, אך מאבדים 28% מהגוף המרבי."
		},
		"echo_shot": {
			"name": "יריית הד",
			"description": "כל מטח חמישי חוזר לאחר השהיה קצרה."
		},
		"breach_hunger": {
			"name": "רעב הפרצה",
			"description": "כניסה לצלילה מעניקה 80% קצב אש למשך 5 שניות."
		},
		"cellular_magnet": {
			"name": "מגנט תאי",
			"description": "חומר ביולוגי נמשך ממרחק כפול."
		},
		"emergency_sheath": {
			"name": "מעטפת חירום",
			"description": "יציאה מאיבר מעניקה מגן שחוסם פגיעה אחת."
		},
		"overclocked_iris": {
			"name": "קשתית מואצת",
			"description": "קליעים נעים 35% מהר יותר ופונים מעט לעבר מטרות."
		},
		"rupture_tax": {
			"name": "מס קריעה",
			"description": "שריון פרצה מפיל 30% יותר חומר ביולוגי."
		},
		"second_skin": {
			"name": "עור שני",
			"description": "מקבלים 22 גוף מרבי ומתקנים 22 מיד."
		},
		"serrated_signal": {
			"name": "אות משונן",
			"description": "כל פגיעה שביעית קורעת רקמה ל־90 נזק נוסף."
		},
		"phase_capacitor": {
			"name": "קבל פאזה",
			"description": "הזינוק נטען 24% מהר יותר."
		},
		"ghost_charge": {
			"name": "מטען רפאים",
			"description": "שומרים מטען זינוק שני, אך כל מטען נטען 12% לאט יותר."
		},
		"wound_memory": {
			"name": "זיכרון הפצע",
			"description": "פצעים שנחשפו לאחרונה סופגים 25% יותר נזק למשך 4 שניות."
		},
		"symbiotic_guard": {
			"name": "משמר סימביוטי",
			"description": "איסוף 18 חומר ביולוגי יוצר מגן לפגיעה אחת."
		},
		"deep_adaptation": {
			"name": "הסתגלות לעומק",
			"description": "גורמים 32% יותר נזק בתוך איברים ו־8% פחות בחוץ."
		},
		"predator_vector": {
			"name": "וקטור טורף",
			"description": "גורמים עד 38% יותר נזק בקרבת המטרה."
		},
		"calm_between_beats": {
			"name": "שקט בין פעימות",
			"description": "הימנעות מנזק במשך 6 שניות מתקנת 3 גוף."
		},
		"infinite_recoil": {
			"name": "רתע אינסופי",
			"description": "כל ירייה צוברת 1% נזק עד לפגיעה בכם, עד 40%."
		}
	},
	"upgrade": {
		"reinforced_hull": {
			"name": "גוף מחוזק",
			"description": "מוסיף 10 גוף מרבי בכל רמה."
		},
		"reactive_plating": {
			"name": "מיגון תגובתי",
			"description": "הפגיעה הראשונה בכל שלב גורמת 40% פחות נזק."
		},
		"starting_sheath": {
			"name": "מעטפת פתיחה",
			"description": "מתחילים כל ריצה עם מגן לפגיעה אחת."
		},
		"phase_coils": {
			"name": "סלילי פאזה",
			"description": "הזינוק נטען 6% מהר יותר בכל רמה."
		},
		"wide_phase": {
			"name": "פאזה רחבה",
			"description": "מאריך את חלון החסינות ב־0.035 שניות."
		},
		"breach_anchor": {
			"name": "עוגן פרצה",
			"description": "פרצות נשארות יציבות 20% יותר זמן."
		},
		"weapon_calibration": {
			"name": "כיול נשק",
			"description": "כל כלי הנשק גורמים 5% יותר נזק בכל רמה."
		},
		"warm_chamber": {
			"name": "תא חם",
			"description": "ב־4 השניות הראשונות של שלב, קצב האש עולה ב־12%."
		},
		"mastery_socket": {
			"name": "שקע שליטה",
			"description": "הנשק המצויד חושף רמז שילוב נוסף."
		},
		"grave_magnet": {
			"name": "מגנט קבר",
			"description": "מגדיל את טווח האיסוף ב־14% בכל רמה."
		},
		"failure_vault": {
			"name": "כספת הכישלון",
			"description": "שומרים 6% יותר חומר ביולוגי לאחר מוות."
		},
		"core_dividend": {
			"name": "דיבידנד ליבה",
			"description": "ניצחון על בוס מעניק 8% יותר חומר ביולוגי."
		},
		"organ_lining": {
			"name": "ריפוד איברים",
			"description": "סכנות פנימיות גורמות 6% פחות נזק בכל רמה."
		},
		"breach_surge": {
			"name": "נחשול פרצה",
			"description": "כניסה לאיבר מתקנת 4 גוף בכל רמה."
		},
		"anatomy_scan": {
			"name": "סריקת אנטומיה",
			"description": "חושף מראש את חוזק רקמת האיבר ואת הסכנה שבתוכו."
		},
		"research_reroll": {
			"name": "ערבוב מחקר",
			"description": "מקבלים ערבוב מוטציות אחד בכל ריצה."
		},
		"rarity_filter": {
			"name": "מסנן נדירות",
			"description": "כל בחירת מוטציה שלישית כוללת אפשרות נדירה."
		},
		"rift_dividend": {
			"name": "דיבידנד קרע",
			"description": "קרעים יומיים וקרעי חברים מעניקים 12% יותר חומר ביולוגי בכל רמה."
		}
	},
	"hazard": {
		"artery_sweep": {"name": "מטאטא העורק"},
		"attack_replay": {"name": "שחזור מתקפה"},
		"beam_grid": {"name": "סריג קרניים"},
		"bone_drones": {"name": "רחפני עצם"},
		"bone_press": {"name": "מכבש עצמות"},
		"brood_wave": {"name": "גל שרצים"},
		"cell_bloom": {"name": "פריחת תאים"},
		"chain_arcs": {"name": "קשתות שרשרת"},
		"chain_defenders": {"name": "מגיני שרשרת"},
		"closing_bone_press": {"name": "מכבש עצמות נסגר"},
		"closing_membranes": {"name": "ממברנות נסגרות"},
		"decoy_bursts": {"name": "פרצי פיתיון"},
		"delayed_clone_fire": {"name": "אש שיבוט מושהית"},
		"delayed_path": {"name": "נתיב מושהה"},
		"egg_hatches": {"name": "בקיעת ביצים"},
		"falling_acid": {"name": "חומצה נופלת"},
		"falling_cells": {"name": "תאים נופלים"},
		"false_lane": {"name": "נתיב מזויף"},
		"inhale_exhale": {"name": "שאיפה ונשיפה"},
		"lateral_current": {"name": "זרם צדדי"},
		"light_gates": {"name": "שערי אור"},
		"mirrored_quadrants": {"name": "רבעים משתקפים"},
		"mirrored_walls": {"name": "קירות משתקפים"},
		"node_arcs": {"name": "קשתות צמתים"},
		"orbiting_defenders": {"name": "מגינים במסלול"},
		"path_replay": {"name": "שחזור נתיב"},
		"pincer_spawn": {"name": "כיתור מלקחיים"},
		"pressure_burst": {"name": "פרץ לחץ"},
		"pulse_gate": {"name": "שער פעימה"},
		"refracted_grid": {"name": "סריג שבור־אור"},
		"refracting_defenders": {"name": "מגינים שוברי־אור"},
		"resonance_pulses": {"name": "פעימות תהודה"},
		"rotating_ribs": {"name": "צלעות מסתובבות"},
		"rotating_wells": {"name": "בארות מסתובבות"},
		"sound_cones": {"name": "חרוטי קול"},
		"suction_cycle": {"name": "מחזור יניקה"},
		"suction_wells": {"name": "בארות יניקה"},
		"tracking_gaze": {"name": "מבט עוקב"},
		"tracking_mites": {"name": "קרדיות עוקבות"},
		"turbine_lanes": {"name": "נתיבי טורבינה"},
		"turbine_sweep": {"name": "מטאטא טורבינה"},
		"vein_walls": {"name": "קירות ורידים"},
		"bone_spikes": {"name": "קוצי עצם"},
		"brood_rush": {"name": "הסתערות שרצים"},
		"choir_pulse": {"name": "פעימת מקהלה"},
		"echo_paths": {"name": "נתיבי הד"},
		"laser_sweep": {"name": "מטאטא לייזר"},
		"memory_echo": {"name": "הד זיכרון"},
		"mirror_walls": {"name": "קירות מראה"},
		"prism_grid": {"name": "סריג מנסרה"},
		"seeking_cells": {"name": "תאים מחפשים"},
		"shock_nodes": {"name": "צמתי הלם"},
		"suction": {"name": "יניקה"},
		"vortex_lane": {"name": "נתיב מערבולת"}
	},
	"room": {
		"tr_membrane_slalom": {"safe_rule": "עקבו אחרי הפתח הבוהק."},
		"tr_vein_switchback": {"safe_rule": "הישארו בין כלי הדם הזוגיים."},
		"tr_rib_corkscrew": {"safe_rule": "נועו עם הפער הרחב ביותר בין הצלעות."},
		"tr_light_duct": {"safe_rule": "חצו רק דרך שערים כבויים."},
		"tr_rift_intestine": {"safe_rule": "השתמשו במערבולת השקטה שבמרכז."},
		"tr_mirror_fold": {"safe_rule": "עקבו אחרי סימן הרקמה הא־סימטרי."},
		"tr_capillary_drop": {"safe_rule": "עברו לסירוגין בין כיס ימין לכיס שמאל."},
		"tr_heartbeat_gate": {"safe_rule": "חצו בין שני הבזקי פעימת הלב."},
		"cb_phagocyte_ring": {"safe_rule": "השאירו נתיב מילוט אחד פתוח."},
		"cb_immune_pincer": {"safe_rule": "שברו תחילה את הצד המסומן."},
		"cb_marrow_drones": {"safe_rule": "השתמשו ברחפנים שהושמדו כמחסה."},
		"cb_optic_mites": {"safe_rule": "שנו כיוון אחרי הבזק המבט."},
		"cb_prism_cherubs": {"safe_rule": "עמדו מאחורי מנסרה עמומה."},
		"cb_choir_mouths": {"safe_rule": "היכנסו אל החרוט השקט."},
		"cb_spark_eels": {"safe_rule": "הפרידו אויבים לפני שהקשתות שלהם מתחברות."},
		"cb_larval_rush": {"safe_rule": "נקו תחילה את פתח הבקיעה הקרוב."},
		"cb_memory_clones": {"safe_rule": "אל תישארו על הנתיב החוזר."},
		"cb_false_cores": {"safe_rule": "ירו בליבה בעלת הפעימה הלא־אחידה."},
		"hz_pressure_pockets": {"safe_rule": "היכנסו לכיס ללא נימים אדומים."},
		"hz_acid_beads": {"safe_rule": "הישארו מתחת לטיפת החומצה הירוקה והאיטית."},
		"hz_bone_press": {"safe_rule": "עברו לצד המסומן באור מח העצם."},
		"hz_gravity_breath": {"safe_rule": "היצמדו מאחורי צלע בזמן השאיפה."},
		"hz_prism_grid": {"safe_rule": "עברו לתא שאינו נדלק לעולם."},
		"hz_turbine_lane": {"safe_rule": "הסתובבו עם הלהב האיטי."},
		"hz_vortex_wells": {"safe_rule": "הקיפו את הבאר הפעילה מבחוץ."},
		"hz_shock_nodes": {"safe_rule": "חצו דרך צומת חשוך כדי לשבור את השרשרת."},
		"hz_echo_paths": {"safe_rule": "עזבו את נתיב התנועה האחרון לפני ההד."},
		"hz_mirror_walls": {"safe_rule": "עברו דרך הפער היחיד שאינו משתקף."},
		"hz_white_cells": {"safe_rule": "עברו מאחורי הפריחה כשהיא נפתחת."},
		"hz_artery_crossing": {"safe_rule": "חצו אחרי גל הלחץ הנראה."},
		"ch_gravemaw_hunter_eye": {"safe_rule": "שברו קשר עין מאחורי רקמת העדשה."},
		"ch_gravemaw_gravity_lung": {"safe_rule": "עברו לסירוגין בין כיסים מעוגנים."},
		"ch_gravemaw_bone_forge": {"safe_rule": "השתמשו בנתיב הצד המסומן."},
		"ch_seraph_prism_cortex": {"safe_rule": "נועו דרך התא הכבוי."},
		"ch_seraph_wing_reactor": {"safe_rule": "נועו עם הסיבוב."},
		"ch_seraph_halo_choir": {"safe_rule": "עמדו בין חזיתות הגל."},
		"ch_leviathan_vortex_stomach": {"safe_rule": "הקיפו את הבאר הפעילה מבחוץ."},
		"ch_leviathan_shock_gland": {"safe_rule": "חצו דרך צמתים כבויים."},
		"ch_leviathan_brood_sac": {"safe_rule": "השמידו את הביצה המסומנת לפני שתבקע."},
		"ch_null_memory_cortex": {"safe_rule": "החליפו נתיב לפני המתקפה המוקלטת."},
		"ch_null_echo_heart": {"safe_rule": "הימנעו מחציית השובל האחרון שלכם."},
		"ch_null_reflection_lattice": {"safe_rule": "עקבו אחרי סימן הרקמה הא־סימטרי."}
	}
}
