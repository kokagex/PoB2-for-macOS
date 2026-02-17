import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { splitMarkdown, type Section } from "./markdown-splitter.js";

describe("splitMarkdown", () => {
  it("splits by h1/h2 headings", () => {
    const md = `# Intro\nHello\n## Part A\nContent A\n## Part B\nContent B`;
    const sections = splitMarkdown(md);
    assert.equal(sections.length, 3);
    assert.equal(sections[0].title, "Intro");
    assert.equal(sections[1].title, "Part A");
    assert.equal(sections[2].title, "Part B");
  });

  it("includes content between headings", () => {
    const md = `# Title\nLine 1\nLine 2\n## Next\nLine 3`;
    const sections = splitMarkdown(md);
    assert.ok(sections[0].content.includes("Line 1"));
    assert.ok(sections[0].content.includes("Line 2"));
    assert.ok(!sections[0].content.includes("Line 3"));
  });

  it("handles preamble before first heading", () => {
    const md = `Some preamble\n# Title\nContent`;
    const sections = splitMarkdown(md);
    assert.equal(sections.length, 2);
    assert.equal(sections[0].title, "Preamble");
  });

  it("returns single section for heading-less doc", () => {
    const md = `Just plain text\nNo headings here`;
    const sections = splitMarkdown(md);
    assert.equal(sections.length, 1);
    assert.equal(sections[0].title, "Document");
  });
});
