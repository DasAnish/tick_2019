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

#define TASK 3

#define PI 3.1415926535897932384626433832795
#define RENDER_DEPTH 800
#define CLOSE_ENOUGH 0.00001

#define BACKGROUND -1
#define BALL 0
#define BASE 1

#define SCENE Torus
#define FULL_SCENE task5

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

///////////////////////////////////////////////////////////////////////////////

float sphere(vec3 pt) {
    return length(pt) - 1;
}

float cube(vec3 pt) {
    vec3 d = abs(pt) - vec3(1);
    return min(max(d.x, max(d.y, d.z)), 0.0) + length(max(d, 0.0));
}

//Implimentations for task2

float smin(float a, float b) {
    float k = 0.2;
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0, 1);

    return mix(b, a, h) - k*h*(1-h);
}

float task2(vec3 pt) {
    float cube1 = cube(pt-vec3(3, 0, 3));
    float cube2 = cube(pt-vec3(-3, 0, 3));
    float cube3 = cube(pt-vec3(-3, 0, -3));
    float cube4 = cube(pt-vec3(3, 0, -3));

    float sphere1 = sphere(pt - vec3(4, 0, 4));
    float sphere2 = sphere(pt - vec3(-2, 0, 4));
    float sphere3 = sphere(pt - vec3(-2, 0, -2));
    float sphere4 = sphere(pt - vec3(4, 0, -2));

    float val1 = max(cube1, sphere1);
    float val2 = smin(cube2, sphere2);
    float val3 = min(cube3, sphere3);
    float val4 = max(cube4, -sphere4);

    return min(min(val1, val2), min(val3, val4));
}

//// Task3

float flr(vec3 pt) {
    return dot(pt-vec3(0, -1, 0), vec3(0, 1, 0));
}

float task3(vec3 pt) {
    float fl = flr(pt);
    float task = task2(pt);
    return min(fl, task);
}

//Task 4
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

float task4(vec3 pt) {
    //    return min(torus(pt-vec3(0, 3, 0)), flr(pt));
    return min(torus(pt), flr(pt));
}

float task5(vec3 pt) {
    return min(Torus(pt), flr(pt));
}

vec3 getNormal(vec3 pt) {
    //  return normalize(GRADIENT (pt, sphere));
    vec3 vec = GRADIENT(pt, FULL_SCENE);
    return normalize(vec);
}

vec3 getColor(vec3 pt) {

    vec3 green = vec3(0.4, 1, 0.4);
    vec3 blue = vec3(0.4, 0.4, 1);

    if (flr(pt)>=CLOSE_ENOUGH) return vec3(1);
    else { //Handling the color

        float dis = abs(SCENE(pt));
        dis = mod(dis, 5);

        if (dis>=4.75) {
            return vec3(0);
        } else {
            dis = mod(dis, 1);
            return mix(green, blue, dis);
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