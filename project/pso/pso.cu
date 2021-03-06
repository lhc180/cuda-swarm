#include <cuda.h>
#include <curand_kernel.h>
#include "pso.h"
#include "../headers/max_func.h"

#define W 1.0
#define C1 1.0
#define C2 1.0

__device__ void src_to_dest(particle * s, particle * d, unsigned int index, unsigned int dim) {
	d[index].pos[dim] = s[index].pos[dim];
	d[index].del[dim] = 0.0;
	d[index].bsf[dim] = s[index].bsf[dim];
}

__device__ float global(particle * s, unsigned int i, unsigned int d) {
	unsigned int pu, pd;
	float a, b, c;

	pu = (i + 1) % DIM;
	pd = (i - 1) % DIM;
	a = s[i].bsf[d];
	b = s[pu].bsf[d];
	c = s[pd].bsf[d];
	
	return (a > b) ? (a > c ? a : c) : (b > c ? b : c);
}

__device__ float inertial(float del) {
	return W * del;
}

__device__ float cognitive(float pos, float bsf) {
	return C1 * (bsf - pos);
}

__device__ float social(particle * s, particle * d, unsigned int i, unsigned int dim) {
	return C2 * (global(s, i, dim) - s[i].pos[dim]);
}

__device__ void update_best(particle * s, particle * d, unsigned int index) {
	if (max_func(s[index].pos) > max_func(s[index].bsf)) {
		for(unsigned int i = 0; i < DIM; i++) {
			d[index].bsf[i] = s[index].pos[i];
		}
	}
}

__device__ void update(particle * s, particle * d, unsigned int index) {
	for(unsigned int i = 0; i < DIM; i++) {
		src_to_dest(s, d, index, i);
		d[index].del[i] += inertial(s[index].del[i]);
		d[index].del[i] += cognitive(s[index].pos[i], s[index].bsf[i]);
		d[index].del[i] += social(s, d, index, i);
		d[index].pos[i] += d[index].del[i];
	}
}

__global__ void pso(blockData * p, bool sw) {
	unsigned int x_i = threadIdx.x + blockIdx.x * blockDim.x;
	unsigned int y_i = threadIdx.y + blockIdx.y * blockDim.y;
	unsigned i = x_i + y_i * blockDim.x * gridDim.x;
	
	particle * s = sw ? (particle *)p->s : (particle *)p->d;
	particle * d = sw ? (particle *)p->d : (particle *)p->s;
	
	if (i < PARTICLE_COUNT) {
		update(s, d, i);
		update_best(s, d, i);
	}
}
