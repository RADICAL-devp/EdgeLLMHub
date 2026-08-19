package com.omoyari.greentech.infrastructure.persistence;

import com.omoyari.greentech.application.ports.DoctorNoteRepository;
import com.omoyari.greentech.core.DoctorNote;
import jakarta.inject.Singleton;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.stream.Collectors;

/**
 * In-memory repository simulating DynamoDB for the POC.
 * Replace with real DynamoDB SDK calls for production.
 */
@Singleton
public class InMemoryDoctorNoteRepository implements DoctorNoteRepository {

    private final Map<String, DoctorNote> notesTable = new ConcurrentHashMap<>();

    @Override
    public DoctorNote save(DoctorNote note) {
        notesTable.put(note.getNoteId(), note);
        return note;
    }

    @Override
    public Optional<DoctorNote> findById(String noteId) {
        return Optional.ofNullable(notesTable.get(noteId));
    }

    @Override
    public List<DoctorNote> findByConsultationId(String consultationId) {
        return notesTable.values().stream()
                .filter(n -> consultationId.equals(n.getConsultationId()))
                .collect(Collectors.toList());
    }

    @Override
    public List<DoctorNote> findByDoctorId(String doctorId) {
        return notesTable.values().stream()
                .filter(n -> doctorId.equals(n.getDoctorId()))
                .collect(Collectors.toList());
    }

    @Override
    public void deleteById(String noteId) {
        notesTable.remove(noteId);
    }
}
