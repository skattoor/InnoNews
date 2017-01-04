/*
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package org.apache.nifi.processors.innonews;

import org.apache.commons.io.IOUtils;

import org.apache.nifi.components.PropertyDescriptor;
import org.apache.nifi.components.PropertyValue;
import org.apache.nifi.flowfile.FlowFile;
import org.apache.nifi.annotation.behavior.ReadsAttribute;
import org.apache.nifi.annotation.behavior.ReadsAttributes;
import org.apache.nifi.annotation.behavior.WritesAttribute;
import org.apache.nifi.annotation.behavior.WritesAttributes;
import org.apache.nifi.annotation.lifecycle.OnScheduled;
import org.apache.nifi.annotation.documentation.CapabilityDescription;
import org.apache.nifi.annotation.documentation.SeeAlso;
import org.apache.nifi.annotation.documentation.Tags;
import org.apache.nifi.processor.exception.ProcessException;
import org.apache.nifi.processor.*;
import org.apache.nifi.processor.io.*;
import org.apache.nifi.processor.util.StandardValidators;

import java.util.*;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicReference;
import java.io.*;

import com.rometools.rome.feed.synd.*;
import com.rometools.rome.io.SyndFeedInput;
import com.rometools.rome.io.XmlReader;

@Tags({"RSS"})
@CapabilityDescription("This processors parses XML RSS feeds (RSS / Atom) flowfiles and generates one flowfile per item, with attributes")
@SeeAlso({})
@ReadsAttributes({@ReadsAttribute(attribute="", description="")})
@WritesAttributes({@WritesAttribute(attribute="description", description="description of the item"),
	@WritesAttribute(attribute="pubDate", description="publication date of the item"),
	@WritesAttribute(attribute="link", description="link of the item"),
	@WritesAttribute(attribute="title", description="title of the item")})

public class ParseRss extends AbstractProcessor {

    public static final Relationship REL_ORG = new Relationship.Builder()
            .name("original")
            .description("The original flowfile will be routed here upon successful parsing")
            .build();
    public static final Relationship REL_ITEMS = new Relationship.Builder()
            .name("items")
            .description("Flowfiles for each news item will be routed here if the RSS/Atom feed was successfully parsed")
            .build();
    public static final Relationship REL_FAILURE	 = new Relationship.Builder()
            .name("failure")
            .description("Flowfiles will be routed here if the URL wasn't successfully parsed")
            .build();

    private List<PropertyDescriptor> descriptors;

    private Set<Relationship> relationships;

    @Override
    protected void init(final ProcessorInitializationContext context) {
/*        final List<PropertyDescriptor> descriptors = new ArrayList<PropertyDescriptor>();
        descriptors.add(URL);
        this.descriptors = Collections.unmodifiableList(descriptors);
		*/

        final Set<Relationship> relationships = new HashSet<Relationship>();
        relationships.add(REL_ORG);
        relationships.add(REL_ITEMS);
        relationships.add(REL_FAILURE);
        this.relationships = Collections.unmodifiableSet(relationships);
    }

    @Override
    public Set<Relationship> getRelationships() {
        return this.relationships;
    }

    @Override
    public final List<PropertyDescriptor> getSupportedPropertyDescriptors() {
        return descriptors;
    }

    @OnScheduled
    public void onScheduled(final ProcessContext context) {

    }

	/* Lessons learned :
	 *		* Don't modify the session inside of the callback
	 *		* Always send all the FlowFiles to a relationship, be it the incoming FlowFile or any 
	 *		generated in your processor
	 */
    @Override
	public void onTrigger(final ProcessContext context, final ProcessSession session) throws ProcessException {
		FlowFile original = session.get();

		if ( original == null ) {
			return;
		}
		AtomicBoolean error = new AtomicBoolean(); // initial value is false
		// We need a local variable to be final to be able to access it in a subclass
		final AtomicReference<SyndFeed> holder = new AtomicReference<>();

		SyndFeedInput input = new SyndFeedInput();

		// Reading the content of the FlowFile
		session.read(original, new InputStreamCallback() {
			@Override
			public void process(InputStream in) throws IOException {
				try {
					SyndFeed feed = input.build(new InputStreamReader(in));
					holder.set(feed);
				} catch (Exception e) {
					getLogger().info("Failed to parse xml file for RSS/Atom feed due to {}", e);
					error.set(true);
				}
			}
		});
		if (error.get()) {
			session.transfer(original, REL_FAILURE);
			return;
		} else {
			try {
				SyndFeed feed = holder.get();
				for (final Iterator iter = feed.getEntries().iterator(); iter.hasNext(); ) {
					FlowFile split = session.create(original);
					final SyndEntry entry = (SyndEntry)iter.next();

					try {
						split = session.putAttribute(split, "title", entry.getTitle());
						if (entry.getPublishedDate() != null) {	
							split = session.putAttribute(split, "pubDate", String.valueOf(entry.getPublishedDate().getTime()));
						}
						if (entry.getDescription() != null) {
							split = session.putAttribute(split, "description", entry.getDescription().getValue());
						}
						split = session.putAttribute(split, "link",entry.getUri());
						session.transfer(split, REL_ITEMS);
					} catch (Exception e) {
						getLogger().info("Something bad happened with this feed item {}. Throwing it away {}", new Object[]{entry, e});
						session.remove(split); // Discarding this split
					}
				}
			} catch (Exception e) {
				getLogger().info("Parsing of feed failed due to {}", e);
				session.transfer(original, REL_FAILURE);
				return;
			}
			session.transfer(original, REL_ORG);
			return;
		}
	}
}
