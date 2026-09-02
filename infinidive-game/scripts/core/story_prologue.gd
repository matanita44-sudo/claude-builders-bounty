class_name StoryPrologue
extends RefCounted

const ENGLISH := {
	"copy": {
		"skip": "SKIP",
		"continue": "CONTINUE",
		"finish": "WAKE THE SPARK",
		"progress": "{current} / {total}",
	},
	"beats": [
		{
			"id": "aion_devoured",
			"eyebrow": "BEFORE THE SKY BROKE",
			"title": "AION WAS DEVOURED",
			"body": "The Titans tore the god of eternity from his throne and swallowed eternity itself.",
			"symbol": "devoured",
			"accent": "#F25F5C",
		},
		{
			"id": "eternal_hunger",
			"eyebrow": "HIS FINAL CURSE",
			"title": "“You wanted eternity — now hunger forever.”",
			"body": "Aion's voice still echoes inside the giants.",
			"symbol": "curse",
			"accent": "#C88936",
		},
		{
			"id": "hero_unarmed",
			"eyebrow": "THE LAST NEST",
			"title": "NO WEAPON",
			"body": "You are its youngest Keeper. No blade. No armor. Only empty hands and Aion's final heartbeat.",
			"symbol": "unarmed",
			"accent": "#2CB8BC",
		},
		{
			"id": "aion_spark",
			"eyebrow": "BENEATH YOUR RIBS",
			"title": "AION'S SPARK WAKES",
			"body": "Time moves again. This time — inside you.",
			"symbol": "spark",
			"accent": "#F1BE48",
		},
	],
}

const HEBREW := {
	"copy": {
		"skip": "דלג",
		"continue": "המשך",
		"finish": "הער את הניצוץ",
		"progress": "{current} / {total}",
	},
	"beats": [
		{
			"id": "aion_devoured",
			"eyebrow": "לפני שהשמיים נשברו",
			"title": "איון נטרף",
			"body": "הטיטאנים קרעו את אל הנצח מכס מלכותו ובלעו את הנצח שחי בתוכו.",
			"symbol": "devoured",
			"accent": "#F25F5C",
		},
		{
			"id": "eternal_hunger",
			"eyebrow": "הקללה האחרונה",
			"title": "״רציתם נצח — תרעבו לנצח.״",
			"body": "קולו של איון עדיין מהדהד בתוך הענקים.",
			"symbol": "curse",
			"accent": "#C88936",
		},
		{
			"id": "hero_unarmed",
			"eyebrow": "הקן האחרון",
			"title": "בלי נשק",
			"body": "אתה השומר הצעיר ביותר שלו. אין להב, אין שריון — רק ידיים ריקות ופעימת הלב האחרונה של איון.",
			"symbol": "unarmed",
			"accent": "#2CB8BC",
		},
		{
			"id": "aion_spark",
			"eyebrow": "מתחת לצלעות",
			"title": "ניצוץ איון מתעורר",
			"body": "הזמן זז שוב. הפעם — בתוכך.",
			"symbol": "spark",
			"accent": "#F1BE48",
		},
	],
}


static func localized(locale: String) -> Dictionary:
	var normalized := locale.to_lower().replace("_","-").get_slice("-",0)
	return (HEBREW if normalized == "he" else ENGLISH).duplicate(true)
