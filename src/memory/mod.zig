const std = @import("std");

// In-memory skeleton with a placeholder BM25-like indexing path
pub const Entry = struct {
    key: []const u8,
    value: []const u8,
};

pub const Document = struct {
    id: []const u8,
    content: []const u8,
};

pub const InvertedEntry = struct {
    term: []const u8,
    doc_indices: std.ArrayList(usize),
};

pub const Memory = struct {
    allocator: std.mem.Allocator,
    entries: std.ArrayList(Entry),
    docs: std.ArrayList(Document),
    inverted: std.ArrayList(InvertedEntry),

    pub fn init(allocator: std.mem.Allocator) Memory {
        return Memory{
            .allocator = allocator,
            .entries = std.ArrayList(Entry).init(allocator),
            .docs = std.ArrayList(Document).init(allocator),
            .inverted = std.ArrayList(InvertedEntry).init(allocator),
        };
    }

    pub fn put(self: *Memory, key: []const u8, value: []const u8) void {
        var i: usize = 0;
        while (i < self.entries.items.len) : (i += 1) {
            const e = self.entries.items[i];
            if (std.mem.eql(u8, e.key, key)) {
                // Free old value before updating
                self.allocator.free(self.entries.items[i].value);
                self.entries.items[i].value = value;
                return;
            }
        }
        const newEntry = Entry{ .key = key, .value = value };
        self.entries.append(newEntry) catch {};
    }

    pub fn get(self: *Memory, key: []const u8) ?[]const u8 {
        for (self.entries.items) |entry| {
            if (std.mem.eql(u8, entry.key, key)) {
                return entry.value;
            }
        }
        return null;
    }

    pub fn indexDocument(self: *Memory, id: []const u8, content: []const u8) void {
        // Append document
        const doc = Document{ .id = id, .content = content };
        self.docs.append(doc) catch {};
        // Lightweight placeholder: tokenize by spaces and index terms
        var i: usize = 0;
        var start: usize = 0;
        const bytes = content;
        while (i <= bytes.len) : (i += 1) {
            const c = if (i < bytes.len) bytes[i] else 0;
            if (c == ' ' or c == '\t' or c == '\n' or c == '\r' or c == 0) {
                if (i > start) {
                    const termSlice = bytes[start..i];
                    const termCopy = self.allocator.dupe(u8, termSlice) catch null;
                    if (termCopy) |t| {
                        self.indexTerm(t, self.docs.items.len - 1);
                    }
                }
                start = i + 1;
            }
        }
    }

    pub fn indexTerm(self: *Memory, term: []const u8, docIndex: usize) void {
        var i: usize = 0;
        var found = false;
        while (i < self.inverted.items.len) : (i += 1) {
            const entry = self.inverted.items[i];
            if (std.mem.eql(u8, entry.term, term)) {
                // Do not mutate in-place to keep patch simple; keep as skeleton
                found = true;
                break;
            }
        }
        if (!found) {
            var newEntry = InvertedEntry{ .term = term, .doc_indices = std.ArrayList(usize).init(self.allocator) };
            newEntry.doc_indices.append(docIndex) catch {};
            self.inverted.append(newEntry) catch {};
        }
    }

    pub fn search(self: *Memory, query: []const u8, limit: usize) []const Document {
        var results = std.ArrayList(Document).init(self.allocator);
        // Simple search: tokenize query, find docs containing any term
        var qterms = std.ArrayList([]const u8).init(self.allocator);
        defer qterms.deinit();
        var qi: usize = 0;
        var qstart: usize = 0;
        while (qi <= query.len) : (qi += 1) {
            const c = if (qi < query.len) query[qi] else 0;
            if (c == ' ' or c == '\t' or c == '\n' or c == '\r' or c == 0) {
                if (qi > qstart) {
                    qterms.append(query[qstart..qi]) catch {};
                }
                qstart = qi + 1;
            }
        }
        // Score docs by term matches
        for (self.docs.items) |doc| {
            var score: usize = 0;
            for (qterms.items) |qterm| {
                var di: usize = 0;
                var dstart: usize = 0;
                while (di <= doc.content.len) : (di += 1) {
                    const c = if (di < doc.content.len) doc.content[di] else 0;
                    if (c == ' ' or c == '\t' or c == '\n' or c == '\r' or c == 0) {
                        if (di > dstart) {
                            const term = doc.content[dstart..di];
                            if (std.mem.eql(u8, term, qterm)) {
                                score += 1;
                            }
                        }
                        dstart = di + 1;
                    }
                }
            }
            if (score > 0) {
                results.append(doc) catch {};
            }
        }
        // Apply limit
        if (results.items.len > limit) {
            return results.items[0..limit];
        }
        return results.toOwnedSlice() catch return &[_]Document{};
    }

    pub fn deinit(self: *Memory) void {
        var i: usize = 0;
        while (i < self.inverted.items.len) : (i += 1) {
            const entry = self.inverted.items[i];
            self.allocator.free(entry.term);
            entry.doc_indices.deinit();
        }
        self.docs.deinit();
        self.inverted.deinit();
        self.entries.deinit();
    }
};

// Simple placeholder type for future expansions
pub const MemoryStore = struct {
    // Placeholder for future in-memory storage mechanisms
};
