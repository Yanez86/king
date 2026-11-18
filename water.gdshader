shader_type canvas_item;

// Anima l'acqua sul terreno già disegnato (vedi bake_ground in main.gd): sui pixel del colore base dell'acqua
// compaiono increspature che scivolano di qualche pixel e svaniscono, ognuna coi suoi tempi.
// Si muove solo a pixel interi, come il resto della pixel art.

uniform vec4 shallow;  // colore base dell'acqua bassa, letto dal foglio del terreno
uniform vec4 deep;     // colore base dell'acqua alta
uniform float ice = 0.0;  // 0..1: quanto è gelata (vedi atmosphere.gd): il ghiaccio si forma a chiazze, poi copre tutto

const vec2 CELL = vec2(12.0, 8.0);  // una increspatura per cella di questa griglia
const float PERIOD = 3.0;          // secondi tra una comparsa e l'altra della stessa increspatura
const float VISIBLE = 0.6;         // parte del periodo in cui si vede

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	bool is_shallow = distance(c, shallow) < 0.01;
	// gelo: ogni pixel d'acqua (azzurro, anche il fondale e l'acqua più scura) diventa ghiaccio, più chiaro dove l'acqua
	// è più chiara; a chiazze di 3x3 pixel, poi tutta; qualche pixel luccica
	vec2 at = floor(UV / TEXTURE_PIXEL_SIZE);
	if (ice > 0.0 && c.b > c.r + 0.15 && hash(floor(at / 3.0) + 7.0) < ice * 1.25 - 0.1) {
		float light = clamp((c.b - 0.38) / 0.2, 0.0, 1.0);
		COLOR = vec4(mix(vec3(0.6, 0.74, 0.82), vec3(0.84, 0.92, 0.95), light), 1.0);
		if (hash(at) > 0.985) COLOR.rgb = vec3(0.96, 0.99, 1.0);
	} else if (ice < 0.3 && (is_shallow || distance(c, deep) < 0.01)) {
		vec2 px = floor(UV / TEXTURE_PIXEL_SIZE);
		vec2 cell = floor(px / CELL);
		float h = hash(cell);
		float life = fract(TIME / PERIOD + h);
		// increspatura ad arco (.XX. sopra X..X), in un punto a caso della cella, scivola verso destra mentre vive
		// (largo 4 + 2 di scivolata: resta dentro la cella, così non si taglia sul bordo)
		vec2 q = px - cell * CELL - floor(vec2(h * (CELL.x - 5.0), fract(h * 13.0) * (CELL.y - 1.0)));
		q.x -= floor(life * 4.0);
		bool arc = (q.y == 0.0 && (q.x == 1.0 || q.x == 2.0)) || (q.y == 1.0 && (q.x == 0.0 || q.x == 3.0));
		if (arc && life < VISIBLE) {
			COLOR = mix(c, vec4(1.0), is_shallow ? 0.15 : 0.1);
		}
	}
}
