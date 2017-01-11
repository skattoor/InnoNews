import org.apache.commons.io.IOUtils
import java.nio.charset.*

def flowFile = session.get();
if(!flowFile) return;

def slurper = new groovy.json.JsonSlurper();

// read the JSON file representing an email
// Dumps the actual message field into the FlowFile
flowFile = session.write(flowFile, { 
	inputStream, outputStream ->
		def text = IOUtils.toString(inputStream, StandardCharsets.UTF_8)
		def obj = slurper.parseText(text)

		if (obj.message) outputStream.write(obj.message.getBytes(StandardCharsets.UTF_8))} as StreamCallback);

session.transfer(flowFile, REL_SUCCESS);
