package com.omoyari.greentech.application.ports;

import com.omoyari.greentech.core.DoctorNote;
import java.util.List;
import java.util.Optional;

public interface DoctorNoteRepository {
    DoctorNote save(DoctorNote note);
    Optional<DoctorNote> findById(String noteId);
    List<DoctorNote> findByConsultationId(String consultationId);
    List<DoctorNote> findByDoctorId(String doctorId);
    void deleteById(String noteId);
}
