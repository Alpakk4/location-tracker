package com.pinglo.tracker.service

import com.pinglo.tracker.model.DiarySubmitPayload
import com.pinglo.tracker.model.RequestPayload
import okhttp3.ResponseBody
import retrofit2.Response
import retrofit2.http.Body
import retrofit2.http.POST

interface SupabaseApi {

    @POST("ping")
    suspend fun ping(@Body payload: RequestPayload): Response<ResponseBody>

    @POST("diary-maker")
    suspend fun fetchDiary(@Body request: Map<String, String>): Response<ResponseBody>

    @POST("diary-submit")
    suspend fun submitDiary(@Body payload: DiarySubmitPayload): Response<ResponseBody>

    @POST("backfill-reframe-home")
    suspend fun backfillReframeHome(
        @Body request: Map<String, @JvmSuppressWildcards Any>,
    ): Response<ResponseBody>
}
