package com.vvtech.phone_agent;

import com.weway.chaken.api.impl.RequestEncryptInterceptor;
import com.weway.chaken.api.impl.ResponseDecryptInterceptor;
import com.weway.chaken.net.HttpClient;
import com.weway.chaken.net.HttpsUtils;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.TimeUnit;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import miniokhttp.FormBody;
import miniokhttp.Interceptor;
import miniokhttp.MiniOkHttpClient;
import miniokhttp.MultipartBody;
import miniokhttp.Request;
import miniokhttp.RequestBody;
import miniokhttp.Response;

/** Fixed identity for the trusted SDK, applied before its signing and encryption. */
public final class TrustedSdkIdentityInterceptor implements Interceptor {
    private final String appKey;
    public TrustedSdkIdentityInterceptor(String appKey) { this.appKey = appKey; }
    public static final String PACKAGE_NAME = "com.vvtech.aiassistant";
    private static final Pattern PART_NAME = Pattern.compile("(?:^|;)\\s*name=\"([^\"]+)\"");

    public static void install(String appKey) {
        // Keep the SDK HttpClient's timeouts, TLS configuration and interceptor order.
        HttpsUtils.SSLParams ssl = HttpsUtils.getSslSocketFactory();
        HttpClient.getInstance().setOkHttpClient(new MiniOkHttpClient.Builder()
                .readTimeout(5, TimeUnit.SECONDS)
                .writeTimeout(5, TimeUnit.SECONDS)
                .connectTimeout(5, TimeUnit.SECONDS)
                .sslSocketFactory(ssl.sSLSocketFactory, ssl.trustManager)
                .hostnameVerifier(HttpsUtils.UnSafeHostnameVerifier)
                .retryOnConnectionFailure(true)
                .addInterceptor(new TrustedSdkIdentityInterceptor(appKey))
                .addInterceptor(new RequestEncryptInterceptor())
                .addInterceptor(new ResponseDecryptInterceptor())
                .build());
    }

    @Override public Response intercept(Chain chain) throws IOException {
        return chain.proceed(normalize(chain.request()));
    }

    Request normalize(Request request) throws IOException {
        String host = request.url().host();
        if (!host.endsWith(".chaken.net.cn")) return request;
        RequestBody body = request.body();
        RequestBody normalized;
        if (body instanceof FormBody) {
            FormBody form = (FormBody) body;
            FormBody.Builder builder = new FormBody.Builder();
            for (int i = 0; i < form.size(); i++) {
                String name = form.name(i);
                builder.addEncoded(encode(name), encode(fixedValue(name, form.value(i))));
            }
            normalized = builder.build();
        } else if (body instanceof MultipartBody) {
            MultipartBody.Builder builder = new MultipartBody.Builder().setType(MultipartBody.FORM);
            for (MultipartBody.Part part : ((MultipartBody) body).parts()) {
                String disposition = part.headers() == null ? null : part.headers().get("Content-Disposition");
                Matcher name = PART_NAME.matcher(disposition == null ? "" : disposition);
                if (name.find() && !disposition.contains("filename=")
                        && (name.group(1).equals("appkey") || name.group(1).equals("packname")
                        || name.group(1).equals("params"))) {
                    ByteArrayOutputStream text = new ByteArrayOutputStream();
                    part.body().writeTo(text);
                    builder.addFormDataPart(name.group(1), fixedValue(name.group(1),
                            new String(text.toByteArray(), StandardCharsets.UTF_8)));
                } else {
                    builder.addPart(part);
                }
            }
            normalized = builder.build();
        } else {
            return request;
        }
        return request.newBuilder().method(request.method(), normalized).build();
    }

    private String fixedValue(String name, String value) {
        if (name.equals("appkey")) return appKey;
        if (name.equals("packname")) return PACKAGE_NAME;
        if (name.equals("params")) {
            return value.replaceAll("(^|&)packname=[^&]*", "$1packname=" + PACKAGE_NAME)
                    .replaceAll("(^|&)appkey=[^&]*", "$1appkey=" + Matcher.quoteReplacement(appKey));
        }
        return value;
    }

    private static String encode(String value) throws IOException {
        return URLEncoder.encode(value, "UTF-8");
    }
}
