package com.omoyari.greentech.application;

import com.omoyari.greentech.application.ports.DoctorNoteRepository;
import com.omoyari.greentech.core.DoctorNote;
import jakarta.inject.Singleton;
import java.util.Optional;

@Singleton
public class DoctorNoteService {
    private final DoctorNoteRepository doctorNoteRepository;

    public DoctorNoteService(DoctorNoteRepository doctorNoteRepository) {
        this.doctorNoteRepository = doctorNoteRepository;
    }

    public DoctorNote syncNote(DoctorNote note) {
        // Implement simple conflict resolution (local draft wins)
        // If the note doesn't exist, save it.
        // If the note exists, update it.
        return doctorNoteRepository.save(note);
    }

    public Optional<DoctorNote> getNoteForConsultation(String consultationId) {
        return doctorNoteRepository.findByConsultationId(consultationId).stream().findFirst();
    }
}
