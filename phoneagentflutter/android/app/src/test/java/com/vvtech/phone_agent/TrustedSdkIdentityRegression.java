package com.vvtech.phone_agent;

import java.io.ByteArrayOutputStream;
import java.net.URLEncoder;
import java.util.Arrays;
import miniokhttp.FormBody;
import miniokhttp.MultipartBody;
import miniokhttp.Request;
import miniokhttp.RequestBody;

/** Guards identity normalization before SDK signing without altering user fields or files. */
public class TrustedSdkIdentityRegression {
    private static void check(boolean condition, String message) {
        if (!condition) throw new AssertionError(message);
    }

    public static void main(String[] args) throws Exception {
        String params = "packname=com.vvtech.aiassistant.dev&name=张三&literal=a%2Bb&deviceid=device";
        FormBody input = new FormBody.Builder()
                .addEncoded("appkey", "10901")
                .addEncoded("packname", "com.vvtech.aiassistant.local")
                .addEncoded("params", URLEncoder.encode(params, "UTF-8"))
                .addEncoded("ts", "1234567890123").build();
        Request request = new Request.Builder().url("https://sdksms.chaken.net.cn/sdk/cert/verfication")
                .post(input).header("versionext", "020002").tag("original").build();
        Request fixed = new TrustedSdkIdentityInterceptor("10090").normalize(request);
        FormBody form = (FormBody) fixed.body();
        check(form.value(0).equals("10090"), "Fixed appkey");
        check(form.value(1).equals("com.vvtech.aiassistant"), "Fixed outer package");
        check(form.value(2).equals(params.replace("com.vvtech.aiassistant.dev", "com.vvtech.aiassistant")),
                "Fixed nested package, preserve Chinese and encoded values");
        check(form.value(3).equals(input.value(3)), "Preserve dynamic timestamp");
        check(fixed.header("versionext").equals("020002") && fixed.tag().equals("original"), "Preserve request metadata");
        Request unrelated = request.newBuilder().url("https://example.com/upload").build();
        check(new TrustedSdkIdentityInterceptor("10090").normalize(unrelated) == unrelated, "Scope to trusted service");

        byte[] file = {0, 1, 2, 10, 13, (byte) 255};
        MultipartBody multipart = new MultipartBody.Builder().setType(MultipartBody.FORM)
                .addFormDataPart("appkey", "10901")
                .addFormDataPart("packname", "com.vvtech.aiassistant.dev")
                .addFormDataPart("params", params)
                .addFormDataPart("file", "log.bin", RequestBody.create(null, file)).build();
        MultipartBody upload = (MultipartBody) new TrustedSdkIdentityInterceptor("10090").normalize(
                new Request.Builder().url("https://filesms.chaken.net.cn/file/file/upload").post(multipart).build()).body();
        ByteArrayOutputStream text = new ByteArrayOutputStream();
        upload.parts().get(0).body().writeTo(text);
        check(text.toString("UTF-8").equals("10090"), "Fixed multipart key");
        text.reset(); upload.parts().get(1).body().writeTo(text);
        check(text.toString("UTF-8").equals("com.vvtech.aiassistant"), "Fixed multipart package");
        text.reset(); upload.parts().get(3).body().writeTo(text);
        check(Arrays.equals(text.toByteArray(), file), "Preserve log file bytes");
        check(upload.parts().get(3) == multipart.parts().get(3), "Preserve file part headers");
        System.out.println("PASS: fixed trusted identity, preserved user fields, timestamp, metadata and upload file");
    }
}
