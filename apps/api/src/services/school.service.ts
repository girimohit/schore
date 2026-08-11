import { SchoolRepository } from "../repositories/school.repository";

export class SchoolService {
  private schoolRepository = new SchoolRepository();

  async getSchoolById(id: string) {
    const school = await this.schoolRepository.findById(id);
    if (!school) {
      throw new Error("School not found");
    }
    return school;
  }

  async getBranding(schoolId: string) {
    const branding =
      await this.schoolRepository.findBrandingBySchoolId(schoolId);
    if (!branding) {
      throw new Error("Branding configuration not found for school");
    }
    return branding;
  }

  async getFeatures(schoolId: string) {
    const features =
      await this.schoolRepository.findFeaturesBySchoolId(schoolId);
    if (!features) {
      throw new Error("Feature flags configuration not found for school");
    }
    return features;
  }
}
