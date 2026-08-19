package com.omoyari.greentech.api;

import com.omoyari.greentech.application.DoctorNoteService;
import com.omoyari.greentech.core.DoctorNote;
import io.micronaut.http.HttpResponse;
import io.micronaut.http.annotation.*;

/**
 * Notes endpoints matching the mobile app contract:
 *   POST /api/v1/notes/sync
 *   GET  /api/v1/notes/consultation/{consultationId}
 *
 * Requires authentication (JWT bearer).
 */
@Controller("/api/v1/notes")
public class NotesController {

    private final DoctorNoteService doctorNoteService;

    public NotesController(DoctorNoteService doctorNoteService) {
        this.doctorNoteService = doctorNoteService;
    }

    @Post("/sync")
    public HttpResponse<DoctorNote> syncNote(@Body DoctorNote note) {
        DoctorNote savedNote = doctorNoteService.syncNote(note);
        return HttpResponse.ok(savedNote);
    }

    @Get("/consultation/{consultationId}")
    public HttpResponse<DoctorNote> getNoteForConsultation(@PathVariable String consultationId) {
        return doctorNoteService.getNoteForConsultation(consultationId)
                .map(HttpResponse::ok)
                .orElse(HttpResponse.notFound());
    }
}
