package com.vvtech.phone_agent

import java.io.File
import java.util.zip.ZipFile
import org.junit.Assert.*
import org.junit.Test

/** Vendor runtime must contain executable constructors and builder chaining. */
class TrustedCallerRuntimeBytecodeTest {
    @Test
    fun chakenRuntimeKnownCrashBytecodeEntriesAreSafe() {
        ZipFile(sourceFile("libs/trusted_caller/runtime/sdk.jar")).use { jar ->
            assertConstructorDoesNotStartWithReturn(
                jar,
                "com/weway/chaken/utils/LogTestUtil.class",
                "()V"
            )
            assertConstructorDoesNotStartWithReturn(
                jar,
                "com/weway/chaken/bean/ChakenNetworkConfig\$Builder.class",
                "()V"
            )
            assertMethodDoesNotStartWithNullReturn(
                jar,
                "com/weway/chaken/bean/ChakenNetworkConfig\$Builder.class",
                "appKey",
                "(Ljava/lang/String;)Lcom/weway/chaken/bean/ChakenNetworkConfig\$Builder;"
            )
            assertMethodDoesNotStartWithNullReturn(
                jar,
                "com/weway/chaken/bean/ChakenNetworkConfig\$Builder.class",
                "appSecret",
                "(Ljava/lang/String;)Lcom/weway/chaken/bean/ChakenNetworkConfig\$Builder;"
            )
        }
    }

    private fun assertConstructorDoesNotStartWithReturn(
        jar: ZipFile,
        entryName: String,
        descriptor: String
    ) {
        val entry = jar.getEntry(entryName)
        assertNotNull("Missing Chaken runtime class: $entryName", entry)

        val firstOpcode = jar.getInputStream(entry).use { input ->
            methodFirstOpcodes(input.readBytes(), "<init>", descriptor, 1)?.firstOrNull()
        }
        assertNotNull("Missing constructor $entryName $descriptor", firstOpcode)
        assertFalse(
            "Constructor $entryName $descriptor starts with return before super(), causing ART VerifyError",
            firstOpcode == JVM_RETURN_OPCODE
        )
    }

    private fun assertMethodDoesNotStartWithNullReturn(
        jar: ZipFile,
        entryName: String,
        methodName: String,
        descriptor: String
    ) {
        val entry = jar.getEntry(entryName)
        assertNotNull("Missing Chaken runtime class: $entryName", entry)

        val firstOpcodes = jar.getInputStream(entry).use { input ->
            methodFirstOpcodes(input.readBytes(), methodName, descriptor, 2)
        }
        assertNotNull("Missing method $entryName $methodName $descriptor", firstOpcodes)
        assertFalse(
            "Method $entryName $methodName $descriptor starts with null return and breaks SDK init chaining",
            firstOpcodes == listOf(JVM_ACONST_NULL_OPCODE, JVM_ARETURN_OPCODE)
        )
    }

    private fun methodFirstOpcodes(
        classBytes: ByteArray,
        targetName: String,
        targetDescriptor: String,
        count: Int
    ): List<Int>? {
        var offset = 0

        fun readU1(): Int {
            return classBytes[offset++].toInt() and 0xFF
        }

        fun readU2(): Int {
            val value = ((classBytes[offset].toInt() and 0xFF) shl 8) or
                (classBytes[offset + 1].toInt() and 0xFF)
            offset += 2
            return value
        }

        fun readU4(): Int {
            val value = ((classBytes[offset].toInt() and 0xFF) shl 24) or
                ((classBytes[offset + 1].toInt() and 0xFF) shl 16) or
                ((classBytes[offset + 2].toInt() and 0xFF) shl 8) or
                (classBytes[offset + 3].toInt() and 0xFF)
            offset += 4
            return value
        }

        fun readU4At(position: Int): Int {
            return ((classBytes[position].toInt() and 0xFF) shl 24) or
                ((classBytes[position + 1].toInt() and 0xFF) shl 16) or
                ((classBytes[position + 2].toInt() and 0xFF) shl 8) or
                (classBytes[position + 3].toInt() and 0xFF)
        }

        check(readU4() == CLASS_MAGIC)
        offset += 4 // minor_version + major_version

        val constantPool = arrayOfNulls<String>(readU2())
        var index = 1
        while (index < constantPool.size) {
            when (readU1()) {
                CONSTANT_UTF8 -> {
                    val length = readU2()
                    constantPool[index] = String(classBytes, offset, length, Charsets.UTF_8)
                    offset += length
                }
                CONSTANT_INTEGER,
                CONSTANT_FLOAT,
                CONSTANT_FIELD_REF,
                CONSTANT_METHOD_REF,
                CONSTANT_INTERFACE_METHOD_REF,
                CONSTANT_NAME_AND_TYPE,
                CONSTANT_INVOKE_DYNAMIC -> offset += 4
                CONSTANT_LONG,
                CONSTANT_DOUBLE -> {
                    offset += 8
                    index += 1
                }
                CONSTANT_CLASS,
                CONSTANT_STRING,
                CONSTANT_METHOD_TYPE,
                CONSTANT_MODULE,
                CONSTANT_PACKAGE -> offset += 2
                CONSTANT_METHOD_HANDLE -> offset += 3
                else -> error("Unsupported constant pool tag")
            }
            index += 1
        }

        offset += 6 // access_flags + this_class + super_class
        repeat(readU2()) { offset += 2 }
        skipMembers(::readU2, ::readU4) { skipped -> offset += skipped }

        repeat(readU2()) {
            offset += 2 // access_flags
            val name = constantPool[readU2()]
            val descriptor = constantPool[readU2()]
            repeat(readU2()) {
                val attributeName = constantPool[readU2()]
                val attributeLength = readU4()
                val attributeStart = offset
                if (name == targetName && descriptor == targetDescriptor && attributeName == "Code") {
                    val codeLength = readU4At(attributeStart + CODE_LENGTH_OFFSET)
                    if (codeLength > 0) {
                        return (0 until minOf(count, codeLength)).map { index ->
                            classBytes[attributeStart + CODE_BYTES_OFFSET + index].toInt() and 0xFF
                        }
                    }
                }
                offset += attributeLength
            }
        }

        return null
    }

    private fun skipMembers(
        readU2: () -> Int,
        readU4: () -> Int,
        skip: (Int) -> Unit
    ) {
        repeat(readU2()) {
            skip(6)
            repeat(readU2()) {
                skip(2)
                skip(readU4())
            }
        }
    }

    private companion object {
        const val JVM_RETURN_OPCODE = 0xB1
        const val JVM_ACONST_NULL_OPCODE = 0x01
        const val JVM_ARETURN_OPCODE = 0xB0
        const val CLASS_MAGIC = 0xCAFEBABE.toInt()
        const val CODE_LENGTH_OFFSET = 4
        const val CODE_BYTES_OFFSET = 8

        const val CONSTANT_UTF8 = 1
        const val CONSTANT_INTEGER = 3
        const val CONSTANT_FLOAT = 4
        const val CONSTANT_LONG = 5
        const val CONSTANT_DOUBLE = 6
        const val CONSTANT_CLASS = 7
        const val CONSTANT_STRING = 8
        const val CONSTANT_FIELD_REF = 9
        const val CONSTANT_METHOD_REF = 10
        const val CONSTANT_INTERFACE_METHOD_REF = 11
        const val CONSTANT_NAME_AND_TYPE = 12
        const val CONSTANT_METHOD_HANDLE = 15
        const val CONSTANT_METHOD_TYPE = 16
        const val CONSTANT_INVOKE_DYNAMIC = 18
        const val CONSTANT_MODULE = 19
        const val CONSTANT_PACKAGE = 20

        fun sourceFile(path: String): File {
            return listOf(
                File(path),
                File("android/app/$path")
            ).first { it.exists() }
        }
    }
}
