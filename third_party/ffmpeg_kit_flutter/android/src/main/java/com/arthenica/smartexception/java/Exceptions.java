package com.arthenica.smartexception.java;

/**
 * smart-exception-java 最小实现(本地化补丁,2026-08)。
 *
 * 原版 com.arthenica:smart-exception-java 已随 ffmpeg-kit 停维从 Maven Central
 * 下架,社区重发布的 ffmpeg-kit AAR 不再传递该依赖,但其类仍引用本类两个静态
 * 方法(见 FFmpegKitConfig/AbstractSession 等,共 7 个类)。此处按调用点补最小
 * 等价实现,行为与原库一致:
 *  - getStackTraceString:堆栈 → 字符串(原库经 StringWriter/PrintWriter 实现)
 *  - registerRootPackage:原库登记根包用于堆栈过滤,本实现保持调用兼容(空实现)。
 */
public final class Exceptions {

    private Exceptions() {
    }

    public static String getStackTraceString(final Throwable throwable) {
        if (throwable == null) {
            return "";
        }
        final java.io.StringWriter stringWriter = new java.io.StringWriter();
        throwable.printStackTrace(new java.io.PrintWriter(stringWriter));
        return stringWriter.toString();
    }

    public static void registerRootPackage(final String rootPackage) {
        // 原库维护根包列表以裁剪堆栈帧;此处无裁剪需求,空实现保持兼容。
    }
}
