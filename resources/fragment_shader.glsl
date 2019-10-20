#version 330

uniform vec2 resolution;
uniform float currentTime;
uniform vec3 camPos;
uniform vec3 camDir;
uniform vec3 camUp;
uniform sampler2D tex;
uniform bool showStepDepth;

in vec3 pos;

out vec3 color;

#define TASK 6

#define PI 3.1415926535897932384626433832795
#define RENDER_DEPTH 1000
#define CLOSE_ENOUGH 0.00001

#define BACKGROUND -1
#define BALL 0
#define BASE 1

//#define SCENE task6
//#define FULL_SCENE getScene

#define GRADIENT(pt, func) vec3( \
    func(vec3(pt.x + 0.0001, pt.y, pt.z)) - func(vec3(pt.x - 0.0001, pt.y, pt.z)), \
    func(vec3(pt.x, pt.y + 0.0001, pt.z)) - func(vec3(pt.x, pt.y - 0.0001, pt.z)), \
    func(vec3(pt.x, pt.y, pt.z + 0.0001)) - func(vec3(pt.x, pt.y, pt.z - 0.0001)))

const vec3 LIGHT_POS[] = vec3[](vec3(5, 18, 10));

///////////////////////////////////////////////////////////////////////////////

vec3 getBackground(vec3 dir) {
    float u = 0.5 + atan(dir.z, -dir.x) / (2 * PI);
    float v = 0.5 - asin(dir.y) / PI;
    vec4 texColor = texture(tex, vec2(u, v));
    return texColor.rgb;
}

vec3 getRayDir() {
    vec3 xAxis = normalize(cross(camDir, camUp));
    return normalize(pos.x * (resolution.x / resolution.y) * xAxis + pos.y * camUp + 5 * camDir);
}

float rotateX(vec3 pt, float time) {
    return pt.x * cos(time) - pt.z * sin(time);
}

float rotateZ(vec3 pt, float time) {
    return pt.x * sin(time) + pt.z * cos(time);
}

///////////////////////////////////////////////////////////////////////////////

float sphere(vec3 pt, float r) {
    return length(pt) - r;
}

float cube(vec3 pt, float s) {
    vec3 d = abs(pt) - vec3(s);
    return min(max(d.x, max(d.y, d.z)), 0.0) + length(max(d, 0.0));
}

//Implimentations for task2

float smin(float a, float b) {
    float k = 0.2;
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0, 1);

    return mix(b, a, h) - k*h*(1-h);
}


float flr(vec3 pt) {
    return dot(pt-vec3(0, -1, 0), vec3(0, 1, 0));
}

float torus(vec3 pt) {
    pt = pt - vec3(0, 3, 0);
    vec2 t = vec2(3, 1);
    vec2 q = vec2(length(pt.xz) - t.x, pt.y);
    return length(q) - t.y;
}

//Task5 Torus
float Torus(vec3 pt) {
    pt = pt - vec3(0, 3, 0);
    vec2 t = vec2(3, 1);
    vec2 q = vec2(length(pt.xy) - t.x, pt.z);
    return length(q) - t.y;
}

//Task6
float octahedron(vec3 pt, float s) {
    pt = abs(pt);
    float m = pt.x + pt.y + pt.z - s;

//    return m*0.57735027;
    vec3 q;

    if (3*pt.x < m) q = pt.xyz;
    else if (3*pt.y < m) q = pt.yzx;
    else if (3*pt.z < m) q = pt.zxy;
    else return m * 0.57735027;

    float K = clamp(0.5 * (q.z-q.y+s), 0.0, s);
    return length(vec3(q.x, q.y-s+K, q.z-K));
}

float outer_frame(vec3 pt, float s) {
    pt = pt - vec3(0, s-1, 0);
//    float t = (pt.y+1.5) * sin(currentTime*0.5);
    float t = currentTime;
    vec3 p = pt;
    pt.x = p.x * cos(t) - p.z * sin(t);
//    pt.y = pt.y/2;
    pt.z = p.x * sin(t) + p.z * cos(t);
    float oct =  octahedron(pt, s);
    float cir = cube(pt, s/2);
    float cir2 = sphere(pt, s/1.5);

    return max(max(-cir, oct), -cir2);
}

float Outer_frame(vec3 pt, float s) {
//    if (pt.x>-4*s && pt.x<4*s) {
//        pt.x = mod(pt.x, 4*s)-2*s;
//    }
    float X = pt.x;
    float val = 10000;
    for (int i = -1; i<2; i+=2) {
        pt = vec3(X + i*4*s, pt.y, pt.z);
        val = min(val, outer_frame(pt, s));
    }

    return val;
}

float box(vec3 pt, float s, float phase) {
        vec3 p = pt;
//        pt.x = rotateX(p, currentTime+phase);
//        pt.z = rotateZ(p, phase+currentTime);
    vec3 q = abs(pt) - vec3(s, 0.001, s);
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0)-0.6;
}

float building(vec3 pt, float s) {
    pt.z = pt.z + 3*s;
    float y = pt.y;
    y = round(y);

    pt.y = pt.y - clamp(round(pt.y), 0, 10);

//    pt.y = mod(pt.y, 1);

    return box(pt, s-2, 10);
}

float cylinder(vec3 pt, vec3 c) {
    return length(pt.xz - c.xy) - c.z;
}

float cuboid(vec3 pt, vec3 b) {
    vec3 q = abs(pt) - b;

    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

float small_cylinder(vec3 pt, float radius, float s) {
    float p = PI/2;
    vec3 PT = pt;
//    float sc1 = small_cylinder(pt, radius, s);

    pt.x = PT.x * cos(p) - PT.y * sin(p);
    pt.y = PT.x * sin(p) + PT.y * cos(p);
    float cube = cuboid(pt, vec3(s, radius*2, s));
    float cylinder = cylinder(pt, vec3(0, 0, radius));

    return max(cylinder, cube);
}

float three_small_cylinder(vec3 pt, float radius, float s) {
    float p = PI/2;
    vec3 PT = pt;
    float sc1 = small_cylinder(pt, radius, s);

    pt.x = PT.x * cos(p) - PT.y * sin(p);
    pt.y = PT.x * sin(p) + PT.y * cos(p);
    float sc2 = small_cylinder(pt, radius, s);

    PT = pt;
    pt.x = rotateX(PT, p);
    pt.z = rotateZ(PT, p);
    float sc3 = small_cylinder(pt, radius, s);

    return min(sc1, min(sc2,sc3));
}

vec3 animate(vec3 pt) {
    float t = mod(currentTime/3, 3);
    float angle = mod(t, 1)*PI / 2;
    vec3 p = pt;
    if (t<1) {
        pt.x = p.x * cos(angle) - p.y * sin(angle);
        pt.y = p.x * sin(angle) + p.y * cos(angle);
    } else if (t < 2) {
        pt.x = p.x * cos(angle) - p.z * sin(angle);
        pt.z = p.x * sin(angle) + p.z * cos(angle);
    } else {
        pt.y = p.y * cos(angle) - p.z * sin(angle);
        pt.z = p.y * sin(angle) + p.z * cos(angle);
    }

    return pt;
}


float final_artifact(vec3 pt, float radius, float s) {
    pt = animate(pt);
    float tsc = three_small_cylinder(pt, radius, s);
    float c = sphere(pt, s-3);

    return max(c, -tsc);

}

float task6(vec3 pt) {
    float fa = final_artifact(pt, 1, 5);
    float of = Outer_frame(pt, 3);
    float plane = building(pt, 4);
    return min(min(of, plane), fa);
}

float getScene(vec3 pt) {
    return min(task6(pt), flr(pt));
}

float FULL_SCENE(vec3 pt) {
    return getScene(pt);
}

float SCENE(vec3 pt) {
    return task6(pt);
}

vec3 getNormal(vec3 pt) {
    //  return normalize(GRADIENT (pt, sphere));
    vec3 vec = GRADIENT(pt, FULL_SCENE);
    return normalize(vec);
}

vec3 getColor(vec3 pt) {

    vec3 green = vec3(0.4, 1, 0.4);
    vec3 blue = vec3(0.4, 0.4, 1);
    vec3 red = vec3(1, 0.4, 0.4);

    if (flr(pt)>=CLOSE_ENOUGH) return vec3(1);
    else { //Handling the color

        float dis = abs(SCENE(pt));
        dis = mod(dis, 5);

        if (dis>=4.75) {
            return vec3(0);
        } else {
            dis = dis * 6 / 4.75;
            dis = mod(dis, 2);
            if (dis>1) {
                dis = mod(dis, 1);
                return mix(green, blue, dis);
            } else {
                dis = mod(dis, 1);
                return mix(blue, red, dis);
            }
        }

    }
}

///////////////////////////////////////////////////////////////////////////////


//Task5 Shadow
float shadow(vec3 pt, vec3 lightPos) {
    vec3 lightDir = normalize(lightPos - pt);

    float kd = 1;
    int step = 0;

    for (float t = 0.1; t < length(lightPos - pt) && step < RENDER_DEPTH && kd > 0.001;) {
        float d = abs(SCENE(pt + t * lightDir));

        if (d<0.001) return 0;
        else kd = min(kd, 16 * d / t);

        t += d;
        step++;
    }

    return kd;
}

float shade(vec3 eye, vec3 pt, vec3 n) {
    float val = 0;

    val += 0.1;  // Ambient

    for (int i = 0; i < LIGHT_POS.length(); i++) {
        vec3 l = normalize(LIGHT_POS[i] - pt);
        float kd = shadow(pt, LIGHT_POS[i]);
        n = normalize(n);
        vec3 r = normalize(reflect(-l, n));
        vec3 v = normalize(eye - pt);
        float diffuse = max(dot(n, l), 0);
        float specular = pow(max(dot(r, v), 0), 256);
        val += kd * (diffuse + specular);
    }
    return val;
}

vec3 illuminate(vec3 camPos, vec3 rayDir, vec3 pt) {
    vec3 c, n;
    n = getNormal(pt);
    c = getColor(pt);
    return shade(camPos, pt, n) * c;
}

///////////////////////////////////////////////////////////////////////////////

vec3 raymarch(vec3 camPos, vec3 rayDir) {
    int step = 0;
    float t = 0;

    for (float d = 1000; step < RENDER_DEPTH && abs(d) > CLOSE_ENOUGH; t += abs(d)) {
        d = FULL_SCENE(camPos + t * rayDir);
        step++;
    }

    if (step == RENDER_DEPTH) {
        return getBackground(rayDir);
    } else if (showStepDepth) {
        return vec3(float(step) / RENDER_DEPTH);
    } else {
        return illuminate(camPos, rayDir, camPos + t * rayDir);
    }
}

///////////////////////////////////////////////////////////////////////////////

void main() {
    color = raymarch(camPos, getRayDir());
}