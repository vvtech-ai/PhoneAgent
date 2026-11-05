// Evaluate the production script with synthetic Android DSL objects, no APK build.
import groovy.json.JsonOutput
import org.codehaus.groovy.control.CompilerConfiguration
import org.codehaus.groovy.control.customizers.ImportCustomizer

class SyntheticAndroid {
    Map buildFeatures = [:]
    Map fields = [:]
    void defaultConfig(Closure action) {
        action.delegate = this
        action.resolveStrategy = Closure.DELEGATE_FIRST
        action()
    }
    void buildConfigField(String type, String name, String value) {
        fields[name] = new groovy.json.JsonSlurper().parseText(value)
    }
}

def android = new SyntheticAndroid()
def configuration = new CompilerConfiguration()
configuration.addCompilationCustomizers(new ImportCustomizer().addImports('org.gradle.api.GradleException'))
def binding = new Binding([
    rootProject: [projectDir: new File(args[0], 'android')],
    project: new Expando(findProperty: { String name -> name == 'dart-defines' ? args[2] : null }),
    android: android,
])
try {
    new GroovyShell(this.class.classLoader, binding, configuration).evaluate(new File(args[1]))
    println(JsonOutput.toJson(android.fields))
} catch (org.gradle.api.GradleException error) {
    System.err.println(error.message)
    System.exit(1)
}
