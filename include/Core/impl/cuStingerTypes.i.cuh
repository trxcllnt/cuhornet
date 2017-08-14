/**
 * @author Federico Busato                                                  <br>
 *         Univerity of Verona, Dept. of Computer Science                   <br>
 *         federico.busato@univr.it
 * @date July, 2017
 * @version v2
 *
 * @copyright Copyright © 2017 cuStinger. All rights reserved.
 *
 * @license{<blockquote>
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * * Redistributions of source code must retain the above copyright notice, this
 *   list of conditions and the following disclaimer.
 * * Redistributions in binary form must reproduce the above copyright notice,
 *   this list of conditions and the following disclaimer in the documentation
 *   and/or other materials provided with the distribution.
 * * Neither the name of the copyright holder nor the names of its
 *   contributors may be used to endorse or promote products derived from
 *   this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 * </blockquote>}
 */
#include "Core/MemoryManager/MemoryManagerConf.hpp"
#include "Core/cuStingerDevice.cuh" //cuStingerDevice
#include "Core/RawTypes.hpp"

namespace custinger {

__device__ __forceinline__
Vertex::Vertex(cuStingerDevice& custinger, vid_t index) :
                                            _custinger(custinger),
                                            _id(index) {
    assert(index < custinger.nV());
    auto data = custinger.basic_data_ptr()[index];
    _degree   = data.degree;
    _edge_ptr = data.neighbor_ptr;
}

__device__ __forceinline__
Vertex::Vertex(cuStingerDevice& custinger) : _custinger(custinger) {}

__device__ __forceinline__
vid_t Vertex::id() const {
    return _id;
}

__device__ __forceinline__
degree_t Vertex::degree() const {
    return _degree;
}

__device__ __forceinline__
vid_t* Vertex::neighbor_ptr() const {
    return reinterpret_cast<vid_t*>(_edge_ptr);
}

__device__ __forceinline__
vid_t Vertex::neighbor_id(degree_t index) const {
    assert(index < _degree);
    return reinterpret_cast<vid_t*>(_edge_ptr)[index];
}

template<typename T>
__device__ __forceinline__
WeightT* Vertex::edge_weight_ptr() const {
    constexpr ETypeSizePS ETYPE_SIZE_PS_D;
    auto ptr = _edge_ptr + EDGES_PER_BLOCKARRAY * ETYPE_SIZE_PS_D[1];
    return reinterpret_cast<WeightT*>(ptr);
}

template<int INDEX>
__device__ __forceinline__
typename std::tuple_element<INDEX, VertexTypes>::type
Vertex::field() const {
    return _custinger.vertex_field_ptr<INDEX>()[_id];
}

__device__ __forceinline__
Edge Vertex::edge(degree_t index) const {
    auto offset = _edge_ptr + index * sizeof(vid_t);
    return Edge(_custinger, offset, EDGES_PER_BLOCKARRAY);
}

//------------------------------------------------------------------------------
/*__device__ __forceinline__
degree_t Vertex::limit() const {
    return _limit;
}*/
/*
__device__ __forceinline__
degree_t* Vertex::degree_ptr() {
    return reinterpret_cast<degree_t*>(_vertex_ptr + sizeof(byte_t*));
}*/

//------------------------------------------------------------------------------
namespace detail {

template<int INDEX = 0>
__device__ __forceinline__
void store_edge(byte_t* const (&load_ptrs)[NUM_EXTRA_ETYPES],
                byte_t*      (&store_ptrs)[NUM_EXTRA_ETYPES]) {
    using T = typename std::tuple_element<INDEX, EdgeTypes>::type;
    *reinterpret_cast<T*>(store_ptrs) = *reinterpret_cast<const T*>(load_ptrs);
    store_edge<INDEX + 1>(load_ptrs, store_ptrs);
}

template<>
__device__ __forceinline__
void store_edge<NUM_EXTRA_ETYPES>(byte_t* const (&)[NUM_EXTRA_ETYPES],
                                  byte_t*       (&)[NUM_EXTRA_ETYPES]) {}
} // namespace detail

//------------------------------------------------------------------------------

__device__ __forceinline__
void Vertex::store(const Edge& edge, degree_t index) {
    /*Edge to_replace(_edge_ptr, index, _limit);

    reinterpret_cast<vid_t*>(_edge_ptr)[index] = edge.dst();
    detail::store_edge(edge._ptrs, to_replace._ptrs);*/
}

//==============================================================================
//==============================================================================

__device__ __forceinline__
Edge::Edge(cuStingerDevice& custinger, byte_t* edge_ptr, int pitch) :
                        _custinger(custinger),
                        _dst_id(*reinterpret_cast<vid_t*>(edge_ptr)),
                        _tmp_vertex(custinger),
                        _src_vertex(_tmp_vertex) {
    const ETypeSizePS ETYPE_SIZE_PS_D;

    _dst_id = *reinterpret_cast<vid_t*>(edge_ptr);
    #pragma unroll
    for (int i = 0; i < NUM_EXTRA_ETYPES; i++)
        _ptrs[i] = edge_ptr + pitch * ETYPE_SIZE_PS_D[i + 1];
}

__device__ __forceinline__
vid_t Edge::src_id() const {
    return _src_id;
}

__device__ __forceinline__
vid_t Edge::dst_id() const {
    return _dst_id;
}

template<typename T>
__device__ __forceinline__
WeightT Edge::weight() const {
    static_assert(sizeof(T) == sizeof(T) && NUM_ETYPES > 1,
                  "weight is not part of edge type list");
    return *reinterpret_cast<WeightT*>(_ptrs[0]);
}

template<typename T>
__device__ __forceinline__
void Edge::set_weight(WeightT weight) {
    static_assert(sizeof(T) == sizeof(T) && NUM_ETYPES > 1,
                  "weight is not part of edge type list");
    *reinterpret_cast<WeightT*>(_ptrs[0]) = weight;
}

template<typename T>
__device__ __forceinline__
TimeStamp1T Edge::time_stamp1() const {
    static_assert(sizeof(T) == sizeof(T) && NUM_ETYPES > 2,
                  "time_stamp1 is not part of edge type list");
    return *reinterpret_cast<TimeStamp1T*>(_ptrs[1]);
}

template<typename T>
__device__ __forceinline__
TimeStamp2T Edge::time_stamp2() const {
    static_assert(sizeof(T) == sizeof(T) && NUM_ETYPES > 3,
                  "time_stamp2 is not part of edge type list");
    return *reinterpret_cast<TimeStamp2T*>(_ptrs[2]);
}

template<int INDEX>
__device__ __forceinline__
typename std::tuple_element<INDEX, EdgeTypes>::type
Edge::field() const {
    using T = typename std::tuple_element<INDEX, EdgeTypes>::type;
    return *reinterpret_cast<T*>(_ptrs[INDEX]);
}

} // namespace custinger
